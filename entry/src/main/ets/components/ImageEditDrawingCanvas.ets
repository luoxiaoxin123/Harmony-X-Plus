import { image } from '@kit.ImageKit';

class ImageEditDrawPoint {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

class ImageEditDrawStroke {
  points: ImageEditDrawPoint[] = [];
  color: string;
  widthRatio: number;

  mode: number;

  constructor(color: string, widthRatio: number, mode: number = 0) {
    this.color = color;
    this.widthRatio = widthRatio;
    this.mode = mode;
  }
}

@Component
export struct ImageEditDrawingCanvas {
  @Prop active: boolean = false;
  @Prop mode: number = 0;
  @Prop source: image.PixelMap | null = null;
  @Prop penColor: string = '#FF3B30';
  @Prop penWidth: number = 5;
  @Prop @Watch('onUndoRequested') undoSignal: number = 0;
  @Prop @Watch('onRedoRequested') redoSignal: number = 0;
  @Prop @Watch('onClearRequested') clearSignal: number = 0;
  onStrokeStarted?: () => void;
  onStrokeCountChanged?: (count: number) => void;

  private context: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private strokes: ImageEditDrawStroke[] = [];
  private undoHistory: ImageEditDrawStroke[][] = [];
  private redoHistory: ImageEditDrawStroke[][] = [];
  private activeStroke: ImageEditDrawStroke | null = null;

  private onUndoRequested(): void {
    if (this.undoHistory.length === 0) {
      return;
    }
    this.redoHistory.push(this.copyStrokes(this.strokes));
    const previous: ImageEditDrawStroke[] | undefined = this.undoHistory.pop();
    if (previous === undefined) {
      return;
    }
    this.strokes = previous;
    this.activeStroke = null;
    this.redraw();
    this.reportStrokeCount();
  }

  private onRedoRequested(): void {
    if (this.redoHistory.length === 0) {
      return;
    }
    this.undoHistory.push(this.copyStrokes(this.strokes));
    const next: ImageEditDrawStroke[] | undefined = this.redoHistory.pop();
    if (next === undefined) {
      return;
    }
    this.strokes = next;
    this.activeStroke = null;
    this.redraw();
    this.reportStrokeCount();
  }

  private onClearRequested(): void {
    if (this.strokes.length === 0) {
      return;
    }
    this.recordUndoSnapshot();
    this.strokes = [];
    this.activeStroke = null;
    this.redraw();
    this.reportStrokeCount();
  }

  private copyStrokes(source: ImageEditDrawStroke[]): ImageEditDrawStroke[] {
    const copy: ImageEditDrawStroke[] = [];
    for (let strokeIndex: number = 0; strokeIndex < source.length; strokeIndex++) {
      const sourceStroke: ImageEditDrawStroke = source[strokeIndex];
      const copiedStroke: ImageEditDrawStroke = new ImageEditDrawStroke(sourceStroke.color,
        sourceStroke.widthRatio, sourceStroke.mode);
      for (let pointIndex: number = 0; pointIndex < sourceStroke.points.length; pointIndex++) {
        const sourcePoint: ImageEditDrawPoint = sourceStroke.points[pointIndex];
        copiedStroke.points.push(new ImageEditDrawPoint(sourcePoint.x, sourcePoint.y));
      }
      copy.push(copiedStroke);
    }
    return copy;
  }

  private recordUndoSnapshot(): void {
    this.undoHistory.push(this.copyStrokes(this.strokes));
    if (this.undoHistory.length > 50) {
      this.undoHistory.shift();
    }
    this.redoHistory = [];
  }

  private onCanvasAreaChanged(_oldValue: Area, _newValue: Area): void {
    this.redraw();
  }

  private pointFromTouch(touch: TouchObject): ImageEditDrawPoint {
    const width: number = Math.max(1, this.context.width);
    const height: number = Math.max(1, this.context.height);
    return new ImageEditDrawPoint(touch.x / width, touch.y / height);
  }

  private onCanvasTouch(event: TouchEvent): void {
    if (!this.active || event.changedTouches.length === 0) {
      return;
    }
    const touch: TouchObject = event.changedTouches[0];
    if (event.type === TouchType.Down) {
      this.beginStroke(this.pointFromTouch(touch));
      return;
    }
    if (event.type === TouchType.Move) {
      this.extendStroke(this.pointFromTouch(touch));
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.activeStroke = null;
      this.reportStrokeCount();
    }
  }

  private beginStroke(point: ImageEditDrawPoint): void {
    if (this.onStrokeStarted !== undefined) {
      this.onStrokeStarted();
    }
    this.recordUndoSnapshot();
    const width: number = Math.max(1, this.context.width);
    const stroke: ImageEditDrawStroke = new ImageEditDrawStroke(this.penColor,
      Math.max(3, this.mode === 1 ? 18 : this.penWidth) / width, this.mode);
    stroke.points.push(point);
    this.strokes.push(stroke);
    this.activeStroke = stroke;
    this.drawDot(point, stroke);
  }

  private extendStroke(point: ImageEditDrawPoint): void {
    const stroke: ImageEditDrawStroke | null = this.activeStroke;
    if (stroke === null || stroke.points.length === 0) {
      return;
    }
    const previous: ImageEditDrawPoint = stroke.points[stroke.points.length - 1];
    stroke.points.push(point);
    if (stroke.mode === 2) { this.mosaicSegment(previous, point); return; }
    this.context.beginPath();
    this.configureStroke(stroke);
    this.context.moveTo(previous.x * this.context.width, previous.y * this.context.height);
    this.context.lineTo(point.x * this.context.width, point.y * this.context.height);
    this.context.stroke();
  }

  private configureStroke(stroke: ImageEditDrawStroke): void {
    this.context.globalCompositeOperation = stroke.mode === 1 ? 'destination-out' : 'source-over';
    this.context.strokeStyle = stroke.color;
    this.context.fillStyle = stroke.color;
    this.context.lineWidth = Math.max(1, stroke.widthRatio * this.context.width);
    this.context.lineCap = 'round';
    this.context.lineJoin = 'round';
  }

  private drawDot(point: ImageEditDrawPoint, stroke: ImageEditDrawStroke): void {
    if (stroke.mode === 2) { this.mosaicSegment(point, point); return; }
    this.context.beginPath();
    this.configureStroke(stroke);
    const radius: number = Math.max(1, this.context.lineWidth / 2);
    this.context.arc(point.x * this.context.width, point.y * this.context.height,
      radius, 0, Math.PI * 2);
    this.context.fill();
  }

  private mosaicSegment(first: ImageEditDrawPoint, last: ImageEditDrawPoint): void {
    const bitmap: image.PixelMap | null = this.source;
    if (bitmap === null) { return; }
    const width: number = this.context.width;
    const height: number = this.context.height;
    if (width <= 0 || height <= 0) { return; }
    const dimensions: image.Size = bitmap.getImageInfoSync().size;
    const cell: number = Math.max(8, Math.round(width / 30));
    const distance: number = Math.hypot((last.x - first.x) * width, (last.y - first.y) * height);
    const steps: number = Math.max(1, Math.ceil(distance / (cell / 2)));
    this.context.globalCompositeOperation = 'source-over';
    for (let index: number = 0; index <= steps; index++) {
      const progress: number = index / steps;
      const x: number = Math.floor((first.x + (last.x - first.x) * progress) * width / cell) * cell;
      const y: number = Math.floor((first.y + (last.y - first.y) * progress) * height / cell) * cell;
      for (let dx: number = -1; dx <= 1; dx++) {
        for (let dy: number = -1; dy <= 1; dy++) {
          const left: number = x + dx * cell;
          const top: number = y + dy * cell;
          if (left < 0 || left >= width || top < 0 || top >= height) { continue; }
          const sx: number = Math.min(dimensions.width - 1, Math.floor((left + cell / 2) * dimensions.width / width));
          const sy: number = Math.min(dimensions.height - 1, Math.floor((top + cell / 2) * dimensions.height / height));
          this.context.drawImage(bitmap, sx, sy, 1, 1, left, top, cell, cell);
        }
      }
    }
  }

  private redraw(): void {
    const width: number = this.context.width;
    const height: number = this.context.height;
    if (width <= 0 || height <= 0) {
      return;
    }
    this.context.clearRect(0, 0, width, height);
    for (let strokeIndex: number = 0; strokeIndex < this.strokes.length; strokeIndex++) {
      this.drawStroke(this.strokes[strokeIndex]);
    }
  }

  private drawStroke(stroke: ImageEditDrawStroke): void {
    if (stroke.points.length === 0) {
      return;
    }
    if (stroke.mode === 2) {
      this.mosaicSegment(stroke.points[0], stroke.points[0]);
      for (let index: number = 1; index < stroke.points.length; index++) {
        this.mosaicSegment(stroke.points[index - 1], stroke.points[index]);
      }
      return;
    }
    if (stroke.points.length === 1) {
      this.drawDot(stroke.points[0], stroke);
      return;
    }
    this.context.beginPath();
    this.configureStroke(stroke);
    const first: ImageEditDrawPoint = stroke.points[0];
    this.context.moveTo(first.x * this.context.width, first.y * this.context.height);
    for (let pointIndex: number = 1; pointIndex < stroke.points.length; pointIndex++) {
      const point: ImageEditDrawPoint = stroke.points[pointIndex];
      this.context.lineTo(point.x * this.context.width, point.y * this.context.height);
    }
    this.context.stroke();
  }

  private reportStrokeCount(): void {
    if (this.onStrokeCountChanged !== undefined) {
      this.onStrokeCountChanged(this.strokes.length);
    }
  }

  build(): void {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .hitTestBehavior(this.active ? HitTestMode.Default : HitTestMode.None)
      .onAreaChange((oldValue: Area, newValue: Area): void => {
        this.onCanvasAreaChanged(oldValue, newValue);
      })
      .onTouch((event: TouchEvent): void => {
        this.onCanvasTouch(event);
      });
  }
}
