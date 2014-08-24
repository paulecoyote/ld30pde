import 'dart:html';
import 'dart:math';

const num TAU = 2.0 * PI;
const num TO_RADIANS = PI / 180.0;

CanvasRenderingContext2D context;
List<Flower> flowers = new List<Flower>();
List<FlowerDescription> flowersDescriptions = new List<FlowerDescription>();
int flowersInGame = 0;
List<Flower> flowersLastPicked = new List<Flower>();
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

final String backgroundColour = "rgba(255,243,228,1)";

bool _addFlowerToGameShowWarning = true;

/// Entry point. All other functions in alpha order.
void main() {
  // Get seed for world. If not set renavigate to default seed.
  seed = window.location.hash;
  if (seed == null || seed.length == 0) window.location.href = "${window.location.href}#YourNameHere";

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
    flowersProperties.add(new FlowerProperties());
    flowersTransforms.add(new FlowerTransform());
  }

  Flower result = flowers[flowersInGame]
        ..desc = flowersDescriptions[flowersInGame]
        ..isActive = false
        ..prop = flowersProperties[flowersInGame]
        ..trans = flowersTransforms[flowersInGame];

  flowersInGame++;
  return result;
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
    ..desc.primaryColour = allColours[9]
    ..desc.secondaryColour = allColours[8]
    ..desc.messages.clear()
    ..desc.messages.addAll(["connect to yourself...", "you've found yourself..."])
    ..isActive = true
    ..trans.x = startCentreX
    ..trans.y = startCentreY
    ..trans.radius = startRadius;

  _updateFlowerMessage(playerFlower.desc, 0);
  _updatePetalCount(playerFlower, 3);
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
  for (int i=0; i<flowersInGame; i++) {
    if (!flowers[i].isActive) continue;

    trans = flowersTransforms[i];
    context.beginPath();
    context.arc(trans.x, trans.y, trans.radius, 0, TAU, false);
    context.fillStyle = flowersDescriptions[i].primaryColour;
    context.fill();
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
    petalCount = 0, petalRadius = 0.0;

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

    for (int j=0; j<props.petalCount; j++)
    {
      angle = j * 2.0 * PI / petalCount;
      px = fx + cos(angle) * outerR;
      py = fy + sin(angle) * outerR;

      context.beginPath();
      context.arc(px, py, petalRadius, 0, TAU, false);
      context.fillStyle = flowersDescriptions[i].secondaryColour;
      context.fill();
    }
  }

  context.restore();
}

void _drawFps() {
  context.fillStyle = "#000000";
  context.fillText("FPS ${fps.round()}",10, 10);
}

void _generateTinyWorld() {
  //TODO: Generate world with just parents
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
  //TODO: Move towards there
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
  seeds.clear();
  seeds.addAll(seed.codeUnits);

  _addPlayerFlowerToGame();
}

void _update(num frameTimestamp) {
  window.requestAnimationFrame(_update);

  num time = new DateTime.now().millisecondsSinceEpoch;
  if (renderTime != null) _updateFps(time);

  if (lastTimestamp == null) lastTimestamp = frameTimestamp;
  else if (frameTimestamp != lastTimestamp) {
    _draw(frameTimestamp, lastTimestamp - frameTimestamp);
  }

  renderTime = time;
  lastTimestamp = frameTimestamp;
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

  num petalCompensation = props.petalRadius * 0.5;
  num flowerRadius = trans.radius + petalCompensation;
  trans.radius = flowerRadius;

  props.petalCount = count;
  num petalRadiusTerm = (count == 0) ? 100 : count;
  num flowerPetalRadius = flowerRadius / (petalRadiusTerm * 0.25);
  props.petalRadius = flowerPetalRadius;

  props.petalOuterRadius = flowerRadius + (flowerPetalRadius * 0.40);

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
  flowersTransforms = new List<FlowerTransform>.generate(maxFlowerCapacity, _warmUpListsFlowersTransform);
  flowers = new List<Flower>.generate(maxFlowerCapacity, _warmUpListsFlowers);
}

Flower _warmUpListsFlowers(int index) => new Flower();
FlowerDescription _warmUpListsFlowerDescription(int index) => new FlowerDescription();
FlowerProperties _warmUpListsFlowersProperties(int index) => new FlowerProperties();
FlowerTransform _warmUpListsFlowersTransform(int index) => new FlowerTransform();

/// Represents a flower
class Flower {
  bool isActive;
  bool get isPlayer => desc.isPlayer;
  void set isPlayer(bool value) { desc.isPlayer = value; }
  FlowerDescription desc;
  FlowerProperties prop;
  FlowerTransform trans;
}

class FlowerDescription {
  bool isPlayer = false;
  String primaryColour = "";
  String secondaryColour = "";
  int messageIndex = -1;
  int messageLength = 0;
  String messageFont = "";
  List<String> messages = new List<String>();
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
  num y = 0.0;
  num radius = 0.0;
  num lastPickedDistance = 0.0;
}
