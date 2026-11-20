import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

const COMPOSER_PHOTO_LIMIT: number = 20;
let exportSequence: number = 0;

export async function writeComposerPhoto(context: common.Context, bitmap: image.PixelMap): Promise<string> {
  const path: string = context.filesDir + '/harmonyx-edited-' + Date.now().toString() + '-' + (++exportSequence) + '.jpg';
  const packer: image.ImagePacker = image.createImagePacker();
  let file: fileIo.File | undefined;
  try {
    const bytes: ArrayBuffer = await packer.packToData(bitmap, { format: 'image/jpeg', quality: 92 });
    file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(file.fd, bytes);
    return fileUri.getUriFromPath(path);
  } catch (error) {
    try { fileIo.unlinkSync(path); } catch (cleanupError) {}
    throw new Error('Unable to export image');
  } finally {
    if (file !== undefined) { try { fileIo.closeSync(file); } catch (error) {} }
    try { await packer.release(); } catch (error) {}
  }
}

class CollageGeometry {
  columns: number;
  rows: number;
  cell: number;

  constructor(count: number, layout: number) {
    this.columns = layout === 0 ? count : layout === 1 ? 1 : Math.ceil(Math.sqrt(count));
    this.rows = Math.ceil(count / this.columns);
    this.cell = Math.max(32, Math.min(620, Math.floor(4096 / Math.max(this.columns, this.rows))));
  }
}

export async function createPhotoCollage(context: common.Context, uris: string[], layout: number): Promise<string> {
  if (uris.length < 2 || uris.length > COMPOSER_PHOTO_LIMIT) { throw new Error('Invalid collage size'); }
  const grid: CollageGeometry = new CollageGeometry(uris.length, layout);
  const canvas: OffscreenCanvas = new OffscreenCanvas(grid.columns * grid.cell, grid.rows * grid.cell);
  const drawing: OffscreenCanvasRenderingContext2D = canvas.getContext('2d');
  drawing.fillStyle = '#FFFFFF';
  drawing.fillRect(0, 0, grid.columns * grid.cell, grid.rows * grid.cell);
  for (let index: number = 0; index < uris.length; index++) {
    let file: fileIo.File | undefined;
    let bitmap: image.PixelMap | undefined;
    let source: image.ImageSource | undefined;
    try {
      file = await fileIo.open(uris[index], fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(file.fd);
      const original: image.Size = (await source.getImageInfo()).size;
      const ratio: number = Math.min(grid.cell / original.width, grid.cell / original.height);
      const width: number = Math.max(1, Math.round(original.width * ratio));
      const height: number = Math.max(1, Math.round(original.height * ratio));
      bitmap = await source.createPixelMap({ desiredSize: { width: width, height: height } });
      const x: number = (index % grid.columns) * grid.cell + (grid.cell - width) / 2;
      const y: number = Math.floor(index / grid.columns) * grid.cell + (grid.cell - height) / 2;
      drawing.drawImage(bitmap, x, y, width, height);
    } finally {
      if (bitmap !== undefined) { try { await bitmap.release(); } catch (error) {} }
      if (source !== undefined) { try { await source.release(); } catch (error) {} }
      if (file !== undefined) { try { fileIo.closeSync(file.fd); } catch (error) {} }
    }
  }
  const output: image.PixelMap = drawing.getPixelMap(0, 0, grid.columns * grid.cell, grid.rows * grid.cell);
  try { return await writeComposerPhoto(context, output); }
  finally { await output.release(); }
}
