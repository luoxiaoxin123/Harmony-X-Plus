const scrollingControllers: WeakSet<Scroller> = new WeakSet<Scroller>();
const canceledControllers: WeakSet<Scroller> = new WeakSet<Scroller>();

export function scrollStarted(scroller: Scroller): void {
  canceledControllers.delete(scroller);
  scrollingControllers.add(scroller);
}

export function scrollStopped(scroller: Scroller): void {
  scrollingControllers.delete(scroller);
}

export function scrollFrame(scroller: Scroller, offset: number,
  state: ScrollState): OnScrollFrameBeginHandlerResult {
  if (state === ScrollState.Scroll) { canceledControllers.delete(scroller); }
  // A fresh drag restores native physics after a press stops inertia.
  return { offsetRemain: state === ScrollState.Fling && canceledControllers.has(scroller) ? 0 : offset };
}

function cancelInertia(scroller: Scroller): boolean {
  if (!scrollingControllers.delete(scroller)) { return false; }
  canceledControllers.add(scroller);
  return true;
}

// The scrollable handles touch-down and stops its animation. An absolute
// scrollTo here would compete with the new drag and can re-layout WaterFlow.
export function stopScrollOnTouch(event: TouchEvent, scroller: Scroller,
  nestedScrollers: Scroller[] = []): HitTestMode {
  if (event.type !== TouchType.Down) { return HitTestMode.Default; }
  let wasScrolling: boolean = cancelInertia(scroller);
  for (let index: number = 0; index < nestedScrollers.length; index++) {
    const nestedWasScrolling: boolean = cancelInertia(nestedScrollers[index]);
    wasScrolling = wasScrolling || nestedWasScrolling;
  }
  // The stopping press belongs to the scroll container, so it can immediately
  // start another drag without accidentally opening the post under the finger.
  return wasScrolling ? HitTestMode.Block : HitTestMode.Default;
}
