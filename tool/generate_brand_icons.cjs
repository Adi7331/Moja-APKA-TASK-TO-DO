// Render the approved PNG mark to Android launcher densities and Windows ICO.
// Requires `sharp` in NODE_PATH; the bundled Codex Node runtime provides it.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const sourcePath = path.join(root, 'assets/branding/dniowka-mark.png');
const source = fs.readFileSync(sourcePath);
const outputSizes = [
  ['android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48],
  ['android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72],
  ['android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96],
  ['android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144],
  ['android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192],
];
const adaptiveIconSize = 432;
const adaptiveIconArtworkSize = 288;
const windowsIconSizes = [16, 24, 32, 48, 64, 128, 256];

function makeWindowsIcon(images) {
  const directory = Buffer.alloc(6 + images.length * 16);
  directory.writeUInt16LE(0, 0);
  directory.writeUInt16LE(1, 2);
  directory.writeUInt16LE(images.length, 4);

  let imageOffset = directory.length;
  images.forEach(({ size, data }, index) => {
    const entryOffset = 6 + index * 16;
    directory.writeUInt8(size === 256 ? 0 : size, entryOffset);
    directory.writeUInt8(size === 256 ? 0 : size, entryOffset + 1);
    directory.writeUInt8(0, entryOffset + 2);
    directory.writeUInt8(0, entryOffset + 3);
    directory.writeUInt16LE(1, entryOffset + 4);
    directory.writeUInt16LE(32, entryOffset + 6);
    directory.writeUInt32LE(data.length, entryOffset + 8);
    directory.writeUInt32LE(imageOffset, entryOffset + 12);
    imageOffset += data.length;
  });

  return Buffer.concat([directory, ...images.map(({ data }) => data)]);
}

async function main() {
  await Promise.all(outputSizes.map(async ([relative, size]) => {
    await sharp(source)
      .resize(size, size)
      .png()
      .toFile(path.join(root, relative));
  }));

  const destination = path.join(
    root,
    'android/app/src/main/res/drawable-nodpi/dniowka_icon_foreground.png',
  );
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  const adaptiveArtwork = await sharp(source)
    .resize(adaptiveIconArtworkSize, adaptiveIconArtworkSize)
    .png()
    .toBuffer();
  await sharp({
    create: {
      width: adaptiveIconSize,
      height: adaptiveIconSize,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([{
      input: adaptiveArtwork,
      left: (adaptiveIconSize - adaptiveIconArtworkSize) / 2,
      top: (adaptiveIconSize - adaptiveIconArtworkSize) / 2,
    }])
    .png()
    .toFile(destination);

  const windowsImages = await Promise.all(windowsIconSizes.map(async (size) => ({
    size,
    data: await sharp(source).resize(size, size).png().toBuffer(),
  })));
  fs.writeFileSync(
    path.join(root, 'windows/runner/resources/app_icon.ico'),
    makeWindowsIcon(windowsImages),
  );
  process.stdout.write('Rendered Dniówka Android and Windows icons.\n');
}

main().catch((error) => {
  process.stderr.write(`${error}\n`);
  process.exitCode = 1;
});
