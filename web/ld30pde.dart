import 'dart:html';
import 'dart:math';

const num TAU = 2.0 * PI;
const num TAU_QUARTER = TAU * 0.25;
const num TO_RADIANS = PI / 180.0;

// Something that takes a minute to go from 0..1 then snaps back again
num animHelperFudge = 0.0;
num animHelperFudgeFast = 0.0;
num animHelperFudgeFaster = 0.0;
num anumHelperFudgeSin = 0.0;
num anumHelperFudgeCos = 0.0;
CanvasRenderingContext2D context;
List<Flower> flowers = new List<Flower>();
List<FlowerDescription> flowersDescriptions = new List<FlowerDescription>();
int flowersInGame = 0;
List<Flower> flowersLastPicked = new List<Flower>();
List<FlowerLerp>flowersLerps = new List<FlowerLerp>();
List<FlowerProperties>flowersProperties = new List<FlowerProperties>();
List<FlowerTransform> flowersTransforms = new List<FlowerTransform>();
num fps;
num fpsAverage;
bool isFingerDown = false;
bool isFpsShown = true;
bool isPaused = false;
num lastTimestamp;
num mainAreaX;
num mainAreaY;
num mainAreaX2;
num mainAreaY2;
/// 500 flowers seems pretty ambitious right now anyway
int maxFlowerCapacity = 500;
String messageFontFamily = "PT Sans Narrow";

CanvasElement playArea;
HtmlElement playAreaParent;
num playAreaHeight = window.innerHeight;//720;
num playAreaWidth = window.innerWidth;//1280;
Flower playerFlower = new Flower();
num renderTime;
String seed;
List<int> seeds = new List<int>();
int seedsLength = 0;
num worldScale = 1.0;

final List<String> allColours =
// Primary
["rgba(241,194,135,1)", "rgba(255,243,228,1)",
"rgba(255,228,194,1)", "rgba(199,143, 73,1)", "rgba(167,108, 34,1)",
// Secondary 1
"rgba(136,138,193,1)", "rgba(242,243,253,1)",
"rgba(192,194,230,1)", "rgba( 85, 88,152,1)", "rgba( 41, 44,102,1)",
// Secondary 2
"rgba( 88,175,133,1)", "rgba(215,247,231,1)",
"rgba(147,216,183,1)", "rgba( 47,137, 94,1)", "rgba( 13, 85, 50,1)"];

final List<String> allColoursNoOpacity =
// Primary
["rgba(241,194,135,0)", "rgba(255,243,228,0)",
"rgba(255,228,194,0)", "rgba(199,143, 73,0)", "rgba(167,108, 34,0)",
// Secondary 1
"rgba(136,138,193,0)", "rgba(242,243,253,0)",
"rgba(192,194,230,0)", "rgba( 85, 88,152,0)", "rgba( 41, 44,102,0)",
// Secondary 2
"rgba( 88,175,133,0)", "rgba(215,247,231,0)",
"rgba(147,216,183,0)", "rgba( 47,137, 94,0)", "rgba( 13, 85, 50,0)"];

final String backgroundColour = "rgba(255,243,228,1)";

bool _addFlowerToGameShowWarning = true;

/// Entry point. All other functions in alpha order.
void main() {
  playArea = querySelector("#playArea");
  playAreaParent = playArea.parent;
  context = playArea.getContext("2d");
  window.onResize.listen(_resizedWindow);
  playArea.onMouseDown.listen(_mouseDown);
  playArea.onMouseLeave.listen(_mouseDone);
  playArea.onMouseOut.listen(_mouseDone);
  playArea.onMouseUp.listen(_mouseDone);
  playArea.onClick.listen(_mouseClicked);

  _warmUpLists();
  _resize(window.innerWidth, window.innerHeight);
  _restart();

  window.onHashChange.listen((e) {_restart(); });
  window.requestAnimationFrame(_update);
}

Flower _addFlowerToGame() {
  assert(flowersInGame <= maxFlowerCapacity);

  if (flowersInGame == maxFlowerCapacity) {
    // ... well we hit a limit. We could either
    // a) preallocate another block
    // b) see if it's alright anyway ;)

    if (_addFlowerToGameShowWarning) {
      print("DEBUG: _addFlowerToGame went over $maxFlowerCapacity ! *ONLY WARNING*");
      _addFlowerToGameShowWarning = false;
    }

    flowers.add(new Flower());
    flowersDescriptions.add(new FlowerDescription());
    flowersLerps.add(new FlowerLerp());
    flowersProperties.add(new FlowerProperties());
    flowersTransforms.add(new FlowerTransform());
  }

  // RESET.  Danger here is:
  // 1. Unnecessary work if we're not recycling
  // 2. Not resetting everything
  //
  // Though keeping these as POD with no functions should help object size
  // in javascript. As functions take up space in the patch table & can be a source of
  // de-optimisation.

  FlowerDescription desc = flowersDescriptions[flowersInGame];
  desc.firstColour = "";
  desc.secondColour = "";
  desc.thirdColour = "";
  desc.firstColourNoA = "";
  desc.secondColourNoA = "";
  desc.thirdColourNoA = "";
  desc.messageIndex = -1;
  desc.messageLength = 0;
  desc.messageFont = "";
  desc.messages.clear();

  FlowerLerp lerp = flowersLerps[flowersInGame];
  lerp.originX = 0.0;
  lerp.destX = 0.0;
  lerp.originY = 0.0;
  lerp.destY = 0.0;
  lerp.originScale = 0.0;
  lerp.destScale = 0.0;
  // t should be between 0 and 1. 1 Means done.
  lerp.t = 1.0;
  lerp.duration = 0.0;
  lerp.originTimestamp = 0;
  lerp.destTimestamp = 0;

  FlowerProperties prop = flowersProperties[flowersInGame];
  prop.petalCount = 0;
  prop.petalRadius = 0.0;
  prop.petalOuterRadius = 0.0;
  prop.messageLength = 0;
  prop.messageOuterRadius = 0.0;
  prop.messageRotation = PI;
  prop.connectionAttempts = 0;
  prop.nextAttemptsMilestone = 0;

  FlowerTransform trans = flowersTransforms[flowersInGame];
  trans.x = 0.0;
  trans.dx = 0.0;
  trans.y = 0.0;
  trans.dy = 0.0;
  trans.radius = 0.0;
  trans.scale = 1.0;
  trans.lastPickedDistance = 0.0;

  Flower flower = flowers[flowersInGame];
  flower.desc = desc;
  flower.isActive = false;
  flower.lerp = lerp;
  flower.prop = prop;
  flower.trans = trans;
  flower.isPlayer = false;

  flowersInGame++;
  return flower;
}

void _addPlayerFlowerToGame() {
  // Not thought about multiplayer
  assert(flowersInGame == 0);

  num startCentreX = mainAreaX * 2.0;
  num startCentreY = mainAreaY * 2.0;
  num startRadius = 20.0;

  playerFlower = _addFlowerToGame();
  playerFlower
    ..desc.isPlayer = true
    ..desc.firstColour = allColours[8]
    ..desc.firstColourNoA = allColoursNoOpacity[8]
    ..desc.secondColour = allColours[7]
    ..desc.secondColourNoA = allColoursNoOpacity[7]
    ..desc.thirdColour = allColours[9]
    ..desc.thirdColourNoA = allColoursNoOpacity[9]
    ..desc.messages.clear()
    ..desc.messages.addAll(["connect to yourself...", "you've found yourself..."])
    ..isActive = true
    ..trans.x = startCentreX
    ..trans.y = startCentreY
    ..trans.radius = startRadius;

  _updateFlowerMessage(playerFlower.desc, 0);
  _updatePetalCount(playerFlower, 5);
}

void _draw(num frameTimestamp, num dt) {
  bool drawFps = isFpsShown && fps != null;

  context.fillStyle = backgroundColour;
  context.fillRect(0, 0, playAreaWidth, playAreaHeight);

  _drawFlowers(frameTimestamp, dt);
  _drawFlowerMessages(frameTimestamp, dt);

  if (drawFps) _drawFps();
}

void _drawFlowers(num frameTimestamp, num dt) {
  _drawFlowerPetals(frameTimestamp, dt);

  // Now draw centres
  //TODO: could organise by colour to stop so many context calls
  //TODO: Also split out everything that isn't active to prevent branch prediction fails.
  //(Totally overthinking this)
  FlowerTransform trans;
  CanvasGradient grad;
  num radius,innerRadius, innerOffset, diameter, x, y;
  for (int i=0; i<flowersInGame; i++) {
    if (!flowers[i].isActive) continue;

    trans = flowersTransforms[i];
    context.beginPath();
    //context.arc(trans.x, trans.y, trans.radius, 0, TAU, false);

    radius = trans.radius;
    innerOffset = radius * 0.05;
    innerRadius = radius * 0.10;
    diameter = radius * 2.0;
    x = trans.x - radius;
    y = trans.y - radius;
    //context.fillStyle = flowersDescriptions[i].firstColour;
    grad = context.createRadialGradient(trans.x - innerOffset, trans.y - innerOffset, innerRadius, trans.x, trans.y, radius);
    grad.addColorStop(0, flowersDescriptions[i].firstColour);
    grad.addColorStop(0.20, flowersDescriptions[i].thirdColour);
    grad.addColorStop(0.70, flowersDescriptions[i].firstColour);
    //grad.addColorStop(0.80, flowersDescriptions[i].thirdColour);
    grad.addColorStop(1, flowersDescriptions[i].secondColourNoA);
    context.fillStyle = grad;
    //context.fill();
    context.fillRect(x, y, diameter, diameter);
  }
}

void _drawFlowerMessages(num frameTimestamp, num dt) {
  context.save(); // save state

  context.textAlign = "center";
  context.fillStyle = allColours[4];
  context.strokeStyle = allColours[4];

  int flowersLen = flowersInGame;
  FlowerDescription desc;
  FlowerProperties props;
  FlowerTransform trans;
  num r = 0.0, outerR = 0.0, px = 0.0, py = 0.0,
    fx = 0.0, fy = 0.0, angle = 0.0, da = 0.0, ds = 0.0,
    messageLength = 0, messageSize = 12.0;
  String message;

  for (int i=0; i<flowersLen; i++) {
    if (!flowers[i].isActive) continue;

    desc = flowersDescriptions[i];
    if (desc.messageIndex < 0) continue;

    message = desc.messages[desc.messageIndex];
    messageLength = message.length;
    trans = flowersTransforms[i];

    fx = trans.x;
    fy = trans.y;
    r = trans.radius;

    props = flowersProperties[i];
    outerR = props.messageOuterRadius;

    context.font = desc.messageFont;

    da = PI / messageLength;
    props.messageRotation = ds = props.messageRotation + (-dt * 0.001);

    for (int j=0; j<messageLength; j++)
    {
      angle = (da * j) + ds;
      px = fx + cos(angle) * outerR;
      py = fy + sin(angle) * outerR;

      context.fillText(message[j], px, py);
    }
  }

  context.restore();
}

void _drawFlowerPetals(num frameTimestamp, num dt) {
  context.save(); // save state
  int flowersLen = flowersInGame;
  FlowerProperties props;
  FlowerTransform trans;
  num r = 0.0, outerR = 0.0, px = 0.0, py = 0.0,
    fx = 0.0, fy = 0.0, angle = 0.0,
    petalCount = 0, petalRadius = 0.0,
    petalFudgeSin = 0.0, petalFudgeCos = 0.0;

  for (int i=0; i<flowersLen; i++) {
    if (!flowers[i].isActive) continue;

    props = flowersProperties[i];
    trans = flowersTransforms[i];

    petalCount = props.petalCount;
    fx = trans.x;
    fy = trans.y;
    angle = TO_RADIANS * (360.0 / props.petalCount);
    r = trans.radius;
    petalRadius = props.petalRadius;
    outerR = props.petalOuterRadius;

    for (int j=0; j<petalCount; j++)
    {
      angle = j * 2.0 * PI / petalCount;
      petalFudgeSin = (petalRadius * 0.02) * sin(angle + (TAU * animHelperFudgeFaster));
      petalFudgeCos = (petalRadius * 0.02) * cos(angle + (TAU * animHelperFudgeFaster));

      px = petalFudgeCos + fx + cos(angle) * outerR;
      py = petalFudgeSin + fy + sin(angle) * outerR;

      context.beginPath();
      context.arc(px, py, petalRadius, 0, TAU, false);
      context.fillStyle = flowersDescriptions[i].secondColour;
      context.fill();
    }
  }

  context.restore();
}

void _drawFps() {
  context.fillStyle = "#000000";
  context.fillText("FPS ${fps.round()}",10, 10);
}

void _generateStartWorld() {
  _addPlayerFlowerToGame();
}

void _generateTinyWorld() {
  FlowerTransform playerTrans = playerFlower.trans;
  FlowerDescription playerDesc = playerFlower.desc;
  FlowerProperties playerProps = playerFlower.prop;

  num parentAngle = (seeds.first % 360) * TO_RADIANS;
  num relativeRadius = 1.5 + (seeds[3 % seedsLength] % 2);

  num startRadius = relativeRadius * playerTrans.radius;
  num startX = playerTrans.x;
  int primeColour = 5 + (seeds[4 % seedsLength] % 5);
  int secondaryColour = 5 + (seeds[1 % seedsLength] % 5);
  int thirdColour = 5 + (seeds[6 % seedsLength] % 5);
  int petalCount = (7 + (seeds[7 % seedsLength] % 5)) | 0x1;

  num parentOrbitRadius = startRadius * 2.0 + (playerProps.messageOuterRadius * 2.0);

  num px = playerTrans.x + cos(parentAngle) * parentOrbitRadius;
  num py = playerTrans.y + sin(parentAngle) * parentOrbitRadius;

  Flower parent = _addFlowerToGame();
  FlowerDescription desc = parent.desc;
  desc..isPlayer = false
    ..firstColour = allColours[primeColour]
    ..firstColourNoA = allColoursNoOpacity[primeColour]
    ..secondColour = allColours[secondaryColour]
    ..secondColourNoA = allColoursNoOpacity[secondaryColour]
    ..thirdColour = allColours[thirdColour]
    ..thirdColourNoA = allColoursNoOpacity[thirdColour]
    ..messages.clear()
    ..messages.addAll(["you will always be my baby", "i love you"]);

  parent
    ..isActive = true
    ..trans.x = px
    ..trans.y = py
    ..trans.radius = startRadius;

  //num parent2Angle = parent1Angle + TAU_QUARTER + ((seeds.last % 180) * TO_RADIANS);

  _updateFlowerMessage(parent.desc, 0);
  _updatePetalCount(parent, petalCount);
}

void _mouseClicked(MouseEvent event) {
  var clientRect = playArea.getBoundingClientRect();
  num x = event.client.x - clientRect.left,
    y = event.client.y - clientRect.top;

  _pickInteraction(x, y);
}

void _mouseDone(MouseEvent event) {
  isFingerDown = false;
}

void _mouseDown(MouseEvent event) {
  isFingerDown = true;
}

/// Expects x and y in terms of canvas x and y
/// TODO: This is going to have be be looked at when scale is used.
void _pickInteraction(num x1, num y1) {
  num x0 = 0.0, y0 = 0.0, distance = 0.0;
  flowersLastPicked.clear();

  FlowerTransform trans;
  FlowerProperties props;
  for (int i=0; i<flowersInGame; i++) {
    if (!flowers[i].isActive) continue;

    trans = flowersTransforms[i];
    x0 = trans.x;
    y0 = trans.y;

    distance = sqrt((x1-x0)*(x1-x0) + (y1-y0)*(y1-y0));

    props = flowersProperties[i];
    if (distance <= props.messageOuterRadius) {
      trans.lastPickedDistance = distance;
      flowersLastPicked.add(flowers[i]);
    }
  }

  if (flowersLastPicked.isEmpty) {
    _pickedSpace(x1, y1);
  } else {
    for (Flower flower in flowersLastPicked) {
      if (flower == playerFlower) _pickedPlayer(x1, y1);
      else _pickedFlower(x1, y1, flower);
    }
  }
}

void _pickedFlower(num x1, num y1, Flower flower) {

}

void _pickedPlayer(num x1, num y1) {
  FlowerDescription desc = playerFlower.desc;
  FlowerProperties prop = playerFlower.prop;
  prop.connectionAttempts = prop.connectionAttempts + 1;

  if (desc.messageIndex == 0) {
    _playerTutorialSelfAware();
  }
  /*
  else if (desc.messageIndex == 1) {
    // TODO: Move tutorial along
  }
  */
  else if (prop.connectionAttempts > prop.nextAttemptsMilestone)
  {
    // Factor for self-confidence here could need tuning
    prop.nextAttemptsMilestone = prop.nextAttemptsMilestone * 2;

    // Increase petals to next odd number (they look better)
    int newPetalCount = prop.petalCount | 0x1;
    if (newPetalCount == prop.petalCount) newPetalCount = newPetalCount + 2;

    _updatePetalCount(playerFlower, newPetalCount);
  }
}

void _pickedSpace(num x1, num y1) {
 FlowerLerp lerp = playerFlower.lerp;
 FlowerTransform trans = playerFlower.trans;
 lerp.t = 0.0;
 lerp.originX = trans.x;
 lerp.originY = trans.y;
 lerp.destX = x1;
 lerp.destY = y1;

 lerp.duration = 2000.0;
 lerp.originTimestamp = new DateTime.now().millisecondsSinceEpoch;
 lerp.destTimestamp = lerp.originTimestamp + lerp.duration;
}

void _playerTutorialSelfAware() {
  FlowerDescription desc = playerFlower.desc;
  FlowerProperties prop = playerFlower.prop;

  prop.nextAttemptsMilestone = 16;

  // Move on to next stage of ftue
  desc.messageIndex = 1;

  _updatePetalCount(playerFlower, 1);
  _generateTinyWorld();
}

void _resize(num width, num height) {
  playAreaHeight = height;
  playAreaWidth = width;//playAreaHeight * 1.777777777777778;

  if (playAreaHeight < 1.0) playAreaHeight = 1.0;
  if (playAreaWidth < 1.0) playAreaWidth = 1.0;

  // So asthetically things should appear within the central area
  mainAreaX = playAreaWidth * 0.25;
  mainAreaX2 = playAreaWidth - mainAreaX;

  mainAreaY = playAreaHeight * 0.25;
  mainAreaY2 = playAreaHeight - mainAreaY;

  //// print ("$playAreaWidth $playAreaHeight $mainAreaX $mainAreaY $mainAreaX2 $mainAreaY2");
  playArea.width = playAreaWidth;
  playArea.height = playAreaHeight;
}

void _resizedWindow(e) {
  _resize(e.currentTarget.innerWidth, e.currentTarget.innerHeight);
}

void _restart() {
  flowersInGame = 0;

  // Use 16 bit character codes as world seed
  // Get seed for world. If not set renavigate to default seed.
  seed = window.location.hash;
  if (seed == null || seed.length == 0) {
   seed = "#YourNameHere";
   window.location.href = "${window.location.href}${seed}";
  }

  seeds.clear();
  seeds.addAll(seed.codeUnits);
  seedsLength = seeds.length;

  _generateStartWorld();
}

/*
int _seedFor(int seedIndex) {
  assert(seedIndex >= 0);
  int i = seedIndex % seedsLength;
  return seeds[i];
}
*/

void _update(num frameTimestamp) {
  window.requestAnimationFrame(_update);

  num time = new DateTime.now().millisecondsSinceEpoch;
  animHelperFudge = (time % 60000) / 60000;
  animHelperFudgeFast  = (time % 6000) / 6000;
  animHelperFudgeFaster  = (time % 2000) / 2000;
  anumHelperFudgeSin = sin(TAU * animHelperFudge);
  anumHelperFudgeCos = cos(TAU * animHelperFudge);

  num dt = 1.0;
  if (renderTime != null) {
    _updateFps(time);
    dt = time - renderTime;
  } else {
    dt = 1;
  }

  if (lastTimestamp == null) lastTimestamp = frameTimestamp;
  else if (frameTimestamp != lastTimestamp) {
    _updateLerps(time, dt);
    _draw(time, dt);
  }

  renderTime = time;
  lastTimestamp = frameTimestamp;
}

/// Right now this assume flowers have 1 lerp each
/// Also assumes it can directly update transforms
/// TODO: Lerp forces, make it seem skiddy.
void _updateLerps(num frameTimestamp, num dt) {
  // Not interested first time around
  if (renderTime == null) return;

  FlowerLerp lerp;
  FlowerTransform trans;
  for (int i=0; i<flowersInGame; i++) {
    if (!flowers[i].isActive) continue;

    lerp = flowersLerps[i];
    if (lerp.t != 1.0) {
      trans = flowersTransforms[i];

      if (renderTime > lerp.destTimestamp) {
        // Jump to dest
        lerp.t = 1.0;
        trans.x = lerp.destX;
        trans.y = lerp.destY;
        //TODO: Leave forces dx and dy alone?
      } else {
        num timeLeft = lerp.destTimestamp - renderTime;
        num t = 1.0 - (timeLeft / lerp.duration);
        lerp.t = t;
        // print ("before: t ${t}    x ${trans.x}    y ${trans.y}  timeLeft ${timeLeft}   lerp.duration ${lerp.duration}");

        // Ease in and out
        t = t * 2.0;
        if (t < 1.0) t = t * t / 2.0;
        else {
          t = t - 1.0;
          t = -0.5 * (t*(t-2.0) - 1.0);
        }

        // lerp
        trans.x = ((1.0-t) * lerp.originX) + (t * lerp.destX);
        trans.y = ((1.0-t) * lerp.originY) + (t * lerp.destY);

        //print ("after: t ${t}    x ${trans.x}    y ${trans.y}");
      }
    }
  }
}

void _updateFlowerMessage(FlowerDescription flower, int index) {
  if (index < 0 || index > flower.messages.length) {
    flower.messageIndex = -1;
    flower.messageLength = 0;
  } else {
    flower.messageIndex = index;
    flower.messageLength = flower.messages[index].length;
  }
}

void _updateFps(num time) {
  fps = 1000.0 / (time - renderTime);
  if (fpsAverage == null) fpsAverage = fps;
  fpsAverage = fps * 0.05 + fpsAverage * 0.95;
}

void _updatePetalCount(Flower flower, int count) {
  FlowerProperties props = flower.prop;
  FlowerTransform trans = flower.trans;
  FlowerDescription desc = flower.desc;

  num petalCompensation = props.petalRadius * 0.25;
  num flowerRadius = trans.radius + petalCompensation;
  trans.radius = flowerRadius;

  props.petalCount = count;
  num petalRadiusTerm = (count == 0) ? 100 : count;
  num flowerPetalRadius = flowerRadius / (petalRadiusTerm * 0.25);
  props.petalRadius = flowerPetalRadius;

  props.petalOuterRadius = flowerRadius + (flowerPetalRadius * 0.15);

  if (desc.messageLength > 0) {
    props.messageOuterRadius = (flowerRadius / (petalRadiusTerm * 0.25)) +
        (trans.radius + (flowerPetalRadius * 0.40)) +
        (desc.messageLength * 1.10);

    num px = (flowerPetalRadius * 0.50).round();
    if (px < 12) px = 12;

    desc.messageFont = "${px}px ${messageFontFamily}";
  } else {
    props.messageOuterRadius = props.petalOuterRadius;
  }
}

/// We cannot control memory allocation... but we can at least give it a good shot.
/// Allocating stuff in time tends to make stuff closer in space.
void _warmUpLists() {
  flowersDescriptions = new List<FlowerDescription>.generate(maxFlowerCapacity, _warmUpListsFlowerDescription);
  flowersProperties = new List<FlowerProperties>.generate(maxFlowerCapacity, _warmUpListsFlowersProperties);
  flowersLerps = new List<FlowerLerp>.generate(maxFlowerCapacity, _warmUpListsFlowersLerps);
  flowersTransforms = new List<FlowerTransform>.generate(maxFlowerCapacity, _warmUpListsFlowersTransform);

  flowers = new List<Flower>.generate(maxFlowerCapacity, _warmUpListsFlowers);
}

Flower _warmUpListsFlowers(int index) => new Flower();
FlowerDescription _warmUpListsFlowerDescription(int index) => new FlowerDescription();
FlowerLerp _warmUpListsFlowersLerps(int index) => new FlowerLerp();
FlowerProperties _warmUpListsFlowersProperties(int index) => new FlowerProperties();
FlowerTransform _warmUpListsFlowersTransform(int index) => new FlowerTransform();

/// Represents a flower
class Flower {
  bool isActive;
  bool get isPlayer => desc.isPlayer;
  void set isPlayer(bool value) { desc.isPlayer = value; }
  FlowerDescription desc;
  FlowerLerp lerp;
  FlowerProperties prop;
  FlowerTransform trans;
}

class FlowerDescription {
  bool isPlayer = false;
  String firstColour = "";
  String secondColour = "";
  String thirdColour = "";
  String firstColourNoA = "";
  String secondColourNoA = "";
  String thirdColourNoA = "";
  int messageIndex = -1;
  int messageLength = 0;
  String messageFont = "";
  List<String> messages = new List<String>();
}

class FlowerLerp {
  num originX = 0.0;
  num destX = 0.0;
  num originY = 0.0;
  num destY = 0.0;
  num originScale = 0.0;
  num destScale = 0.0;
  // t should be between 0 and 1. 1 Means done.
  num t = 1.0;
  num duration = 0.0;
  num originTimestamp = 0;
  num destTimestamp = 0;
}

class FlowerProperties {
  int petalCount = 0;
  num petalRadius = 0.0;
  num petalOuterRadius = 0.0;

  int messageLength = 0;
  num messageOuterRadius = 0.0;
  num messageRotation = PI;

  int connectionAttempts = 0;
  int nextAttemptsMilestone = 0;
}

/// Warn: Prob should keep this to transform stuff and break down message bloat
/// into other classes to prevent cache missing for doing transforms
class FlowerTransform {
  num x = 0.0;
  num dx = 0.0;
  num y = 0.0;
  num dy = 0.0;
  num radius = 0.0;
  num scale = 1.0;
  num lastPickedDistance = 0.0;
}
