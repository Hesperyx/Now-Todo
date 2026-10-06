// 图标与启动页的机械防线。
//
// 这一批资源的失效方式全是「看不出来」：自适应图标少一层，Android 8 上会看到
// 一个被裁掉角的标志；单色层与前层形状不一致，开了「主题图标」的用户看到的是
// 另一个应用；启动页少了 `windowSplashScreenBackground`，Android 12 上会先闪一屏
// 系统默认色。编译不报、跑起来也不报。
//
// 所以这里直接咬仓库里的文件：XML 的接线、PNG 的真实尺寸与像素格式，
// 以及「生成脚本里的比例」与「资源里实际画出来的东西」是否还对得上。

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// 读仓库里的一个文件；找不到就当场给出「工作目录在哪」的线索。
String readRepoFile(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    fail('找不到 $path。测试的工作目录应该就是包根，实际是 ${Directory.current.path}');
  }
  return file.readAsStringSync();
}

/// 只读 PNG 头。这里不需要解码像素，宽高与颜色类型都在 IHDR 里，偏移固定。
({int width, int height, int colorType}) readPngHeader(String path) {
  final Uint8List bytes = File(path).readAsBytesSync();
  const List<int> signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  expect(bytes.sublist(0, 8), signature, reason: '$path 不是 PNG（连文件头都不对）');
  int readUint32(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  return (width: readUint32(16), height: readUint32(20), colorType: bytes[25]);
}

/// 去掉 XML 注释。断言「这个文件里**没有**某个元素」时，注释里提到它也算命中，
/// 而这些资源文件恰好都带着解释性注释。
String stripXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// 一档密度的资源前缀。自适应图标的前景层画布是 108dp，所以它的像素尺寸
/// 就是密度倍数乘以 108——这几组数字对不上，说明有人手改过某一张图。
const Map<String, ({int icon, int foreground})> densities =
    <String, ({int icon, int foreground})>{
      'mdpi': (icon: 48, foreground: 108),
      'hdpi': (icon: 72, foreground: 162),
      'xhdpi': (icon: 96, foreground: 216),
      'xxhdpi': (icon: 144, foreground: 324),
      'xxxhdpi': (icon: 192, foreground: 432),
    };

void main() {
  const String res = 'android/app/src/main/res';

  group('传统图标', () {
    for (final MapEntry<String, ({int icon, int foreground})> density
        in densities.entries) {
      test('${density.key} 的边长是 ${density.value.icon}px', () {
        final ({int width, int height, int colorType}) header = readPngHeader(
          '$res/mipmap-${density.key}/ic_launcher.png',
        );
        expect(header.width, density.value.icon);
        expect(header.height, density.value.icon);
        expect(header.colorType, 6, reason: '圆角之外要透明，必须是带 alpha 的 PNG');
      });
    }
  });

  group('自适应图标', () {
    test('五档密度的前景层与单色层都在，画布是 108dp 的倍数', () {
      for (final MapEntry<String, ({int icon, int foreground})> density
          in densities.entries) {
        for (final String name in <String>[
          'ic_launcher_foreground.png',
          'ic_launcher_monochrome.png',
        ]) {
          final ({int width, int height, int colorType}) header = readPngHeader(
            '$res/mipmap-${density.key}/$name',
          );
          expect(
            header.width,
            density.value.foreground,
            reason:
                '${density.key}/$name 的画布应当是 108dp × ${density.value.icon / 48}',
          );
          expect(header.height, density.value.foreground);
          expect(header.colorType, 6, reason: '前景层与单色层都必须能透出背景层');
        }
      }
    });

    test('背景 + 前景 + 单色三层各就各位', () {
      // 注释里也会出现 `<monochrome>` 这个词（文件自己在解释为什么不放），
      // 所以先剥掉注释再断言——不然测试会被自己的说明文字绊倒。
      final String v26 = stripXmlComments(
        readRepoFile('$res/mipmap-anydpi-v26/ic_launcher.xml'),
      );
      final String v33 = stripXmlComments(
        readRepoFile('$res/mipmap-anydpi-v33/ic_launcher.xml'),
      );

      expect(
        v26,
        contains(
          '<background android:drawable="@drawable/ic_launcher_background" />',
        ),
      );
      expect(
        v26,
        contains(
          '<foreground android:drawable="@mipmap/ic_launcher_foreground" />',
        ),
      );
      expect(
        v26,
        isNot(contains('<monochrome')),
        reason: '<monochrome> 是 API 33 的元素，放在 v26 里属于「老版本读不懂的文件」',
      );

      expect(
        v33,
        contains(
          '<monochrome android:drawable="@mipmap/ic_launcher_monochrome" />',
        ),
      );
      // 三层里只要少一层，Android 13 的主题图标就会拿前景层硬染一遍，
      // 于是同一个应用在两种模式下长得不一样。
      expect(v33, contains('@drawable/ic_launcher_background'));
      expect(v33, contains('@mipmap/ic_launcher_foreground'));
    });

    test('清单指向 @mipmap/ic_launcher', () {
      final String manifest = readRepoFile(
        'android/app/src/main/AndroidManifest.xml',
      );
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    });
  });

  group('生成脚本与资源必须一致', () {
    late String generator;
    late String background;

    setUpAll(() {
      generator = readRepoFile('tool/app_icon/generate_icons.py');
      background = readRepoFile('$res/drawable/ic_launcher_background.xml');
    });

    test('两边的品牌色是同一组数值', () {
      // 图标的背景有两条生成路径：脚本画的传统图标（PNG）与这里声明的
      // 自适应图标背景（XML）。改了一边忘另一边，不同启动器下会看到两种深青。
      expect(generator, contains('BRAND_TOP = (0x35, 0x7A, 0x6B)'));
      expect(generator, contains('BRAND_BOTTOM = (0x1F, 0x4B, 0x42)'));
      expect(background, contains('android:startColor="#357A6B"'));
      expect(background, contains('android:endColor="#1F4B42"'));
    });

    test('前景层的符号收在 66dp 安全圆内', () {
      // Android 保证不被任何遮罩切到的是直径 66dp 的圆；脚本按 60dp 画，
      // 并且每次生成时逐像素量一遍（超了脚本自己会失败）。这里咬住这两个数，
      // 防止有人为了让图标「大一点」直接改比例。
      expect(generator, contains('60.0 / 108.0'));
      expect(generator, contains('33.0 / 108.0'));
      expect(generator, contains('if ratio > limit'));
    });

    test('单色层与前景层形状一致', () {
      // 单色层用白色画：系统按用户主题染色，形状必须跟前层一样。
      expect(
        generator,
        contains(
          'adaptive_foreground(foreground_size, color=(255, 255, 255, 255))',
        ),
      );
      expect(
        generator,
        contains('adaptive_foreground(foreground_size, color=(*RING, 255))'),
      );
    });
  });

  group('启动页', () {
    test('两个 drawable 变体都是「品牌色 + 居中标志」', () {
      for (final String path in <String>[
        '$res/drawable/launch_background.xml',
        '$res/drawable-v21/launch_background.xml',
      ]) {
        final String xml = readRepoFile(path);
        expect(xml, contains('@color/launch_background'), reason: path);
        expect(xml, contains('@mipmap/ic_launcher_foreground'), reason: path);
      }
    });

    test('Android 12+ 的闪屏背景色在浅色与深色下都声明了', () {
      // 深色的限定符优先级高于版本号，所以 values-night 会盖掉 values-v31：
      // 只写 v31 的话，深色用户拿到的启动页还是系统默认色。
      for (final String path in <String>[
        '$res/values-v31/styles.xml',
        '$res/values-night-v31/styles.xml',
      ]) {
        final String xml = readRepoFile(path);
        expect(
          xml,
          contains('android:windowSplashScreenBackground'),
          reason: '$path 少了这一条，Android 12 会先闪一屏系统默认色',
        );
        expect(xml, contains('@color/launch_background'), reason: path);
        // 两个变体各自是完整的样式定义（资源选择只挑一个，不会合并），
        // 所以 windowBackground 必须两边都写。
        expect(xml, contains('android:windowBackground'), reason: path);
      }
    });

    test('启动底色有浅色与深色两份', () {
      expect(
        readRepoFile('$res/values/colors.xml'),
        contains('name="launch_background"'),
      );
      expect(
        readRepoFile('$res/values-night/colors.xml'),
        contains('name="launch_background"'),
        reason: '深色模式启动时不该被一屏亮青色闪到',
      );
    });
  });

  group('商店素材', () {
    test('512×512 的商店图标是方图且不带透明通道', () {
      final ({int width, int height, int colorType}) header = readPngHeader(
        'docs/store/icon-512.png',
      );
      expect(header.width, 512);
      expect(header.height, 512);
      expect(header.colorType, 2, reason: '商店图应当是 RGB——透明通道只会在别人复用这张图时出问题');
    });

    test('特色图片是 1024×500 且不带透明通道', () {
      // 商店对特色图片的硬要求：1024×500、24 位 PNG（或 JPEG）、不能有 alpha。
      // 尺寸写错或者顺手存成 RGBA，控制台会直接拒，所以要盯着。
      final ({int width, int height, int colorType}) header = readPngHeader(
        'docs/store/feature-graphic.png',
      );
      expect(header.width, 1024);
      expect(header.height, 500);
      expect(header.colorType, 2);
    });

    test('特色图片的生成脚本与图标脚本共用同一份品牌色', () {
      final String script = readRepoFile(
        'tool/app_icon/generate_store_assets.py',
      );
      expect(script, contains('import generate_icons as icons'));
      expect(script, contains('icons.BRAND_TOP'));
      expect(script, contains('icons.RING'));
      expect(
        script,
        contains('WIDTH, HEIGHT = 1024, 500'),
        reason: '尺寸要写成常量，别散在代码里',
      );
    });
  });

  group('前景层的像素真的落在安全圆里', () {
    test('最高的那一档也不能超出 66dp 半径', () async {
      // 上面那些断言咬的是「接线」与「脚本里的比例」，这一条咬的是**画出来的像素**：
      // 解码 xxxhdpi 的前景层，量最远的非透明像素离中心多远。
      // 这是唯一能发现「脚本比例对、但坐标写歪了」的检查。
      final Uint8List bytes = File(
        '$res/mipmap-xxxhdpi/ic_launcher_foreground.png',
      ).readAsBytesSync();
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
        bytes,
      );
      final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(
        buffer,
      );
      final ui.Codec codec = await descriptor.instantiateCodec();
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      addTearDown(image.dispose);

      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(data, isNotNull);

      final ByteData pixels = data!;
      final int size = image.width;
      final double center = size / 2;
      double farthest = 0;
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final int alpha = pixels.getUint8((y * size + x) * 4 + 3);
          if (alpha <= 8) {
            continue;
          }
          final double dx = x - center;
          final double dy = y - center;
          final double distance = math.sqrt(dx * dx + dy * dy);
          if (distance > farthest) {
            farthest = distance;
          }
        }
      }

      final double ratio = farthest / size;
      expect(
        ratio,
        lessThanOrEqualTo(33.0 / 108.0),
        reason:
            '最远像素半径 $ratio（画布比例）超过了 66dp 安全圆（${33.0 / 108.0}）——'
            '某些启动器的遮罩会切到它',
      );
      // 太小同样有问题：符号缩成一小团，48px 下认不出来。
      expect(ratio, greaterThan(0.25), reason: '符号太小，图标在启动器里会显得空');
    });
  });
}
