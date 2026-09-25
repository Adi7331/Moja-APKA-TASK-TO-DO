// Render the approved SVG mark to the Android launcher densities and the UI.
// Requires `sharp` in NODE_PATH; the bundled Codex Node runtime provides it.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(
  path.join(root, 'assets/branding/dniowka-mark.svg'),
  'utf8',
);
const outputSizes = [
  ['assets/branding/dniowka-mark.png', 1024],
  ['android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48],
  ['android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72],
  ['android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96],
  ['android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144],
  ['android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192],
];

async function main() {
  await Promise.all(outputSizes.map(async ([relative, size]) => {
    await sharp(Buffer.from(source), { density: 384 })
      .resize(size, size)
      .png()
      .toFile(path.join(root, relative));
  }));

  const foreground = source
    .replace('viewBox="0 0 512 512"', 'viewBox="-80 -80 672 672"')
    .replace('<rect width="512" height="512" rx="116" fill="#2369ED"/>', '');
  const destination = path.join(
    root,
    'android/app/src/main/res/drawable-nodpi/dniowka_icon_foreground.png',
  );
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  await sharp(Buffer.from(foreground), { density: 384 })
    .resize(432, 432)
    .png()
    .toFile(destination);
  process.stdout.write('Rendered Dniówka PNG and adaptive icons.\n');
}

main().catch((error) => {
  process.stderr.write(`${error}\n`);
  process.exitCode = 1;
});
