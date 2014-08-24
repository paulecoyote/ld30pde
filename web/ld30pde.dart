import 'dart:html';
import 'dart:math';

const num TAU = 2.0 * PI;
const num TO_RADIANS = PI / 180.0;

CanvasRenderingContext2D context;
List<Flower> flowers = new List<Flower>();
List<Flower> flowersLastPicked = new List<Flower>();
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

void main() {
  // Get seed for world. If not set renavigate to default seed.
  seed = window.location.hash;
  if (seed == null || seed == "") window.location.href = "${window.location.href}#YourNameHere";

  playArea = querySelector("#playArea");
  playAreaParent = playArea.parent;
  context = playArea.getContext("2d");
  window.onResize.listen(_resizedWindow);
  playArea.onMouseDown.listen(_mouseDown);
  playArea.onMouseLeave.listen(_mouseDone);
  playArea.onMouseOut.listen(_mouseDone);
  playArea.onMouseUp.listen(_mouseDone);
  playArea.onClick.listen(_mouseClicked);

  _resize(window.innerWidth, window.innerHeight);

  _restart();

  window.requestAnimationFrame(_update);
}

void _createPlayerFlower() {
  num startCentreX = mainAreaX * 2.0;
  num startCentreY = mainAreaY * 2.0;
  num startRadius = 20.0;

  String startMessage = "connect to yourself...";

  playerFlower = new Flower();
  playerFlower..x = startCentreX
      ..y = startCentreY
      ..radius = startRadius
      ..primaryColour = allColours[9]
      ..secondaryColour = allColours[8];

  _updateFlowerMessage(playerFlower, startMessage);
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
  int flowersLen = flowers.length;
  Flower flower;
  for (int i=0; i<flowersLen; i++) {
    flower = flowers[i];
    context.beginPath();
    context.arc(flower.x, flower.y, flower.radius, 0, TAU, false);
    context.fillStyle = flower.primaryColour;
    context.fill();
  }
}

void _drawFlowerMessages(num frameTimestamp, num dt) {
  context.save(); // save state

  context.textAlign = "center";
  context.fillStyle = allColours[4];
  context.strokeStyle = allColours[4];

  int flowersLen = flowers.length;
  Flower flower;
  num r = 0.0, outerR = 0.0, px = 0.0, py = 0.0,
    fx = 0.0, fy = 0.0, angle = 0.0, da = 0.0, ds = 0.0,
    messageLength = 0, messageSize = 12.0;
  String message;

  for (int i=0; i<flowersLen; i++) {
    flower = flowers[i];
    message = flower.message;
    if (message == null) continue;

    messageLength = message.length;
    fx = flower.x;
    fy = flower.y;

    r = flower.radius;
    outerR = flower.messageOuterRadius;

    context.font = flower.messageFont;

    da = PI / messageLength;
    flower.messageRotation = ds = flower.messageRotation + (-dt * 0.001);

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
  int flowersLen = flowers.length;
  Flower flower;
  num r = 0.0, outerR = 0.0, px = 0.0, py = 0.0,
    fx = 0.0, fy = 0.0, angle = 0.0,
    petalCount = 0, petalRadius = 0.0;

  for (int i=0; i<flowersLen; i++) {
    flower = flowers[i];
    petalCount = flower.petalCount;
    fx = flower.x;
    fy = flower.y;
    angle = TO_RADIANS * (360.0 / flower.petalCount);
    r = flower.radius;
    petalRadius = flower.petalRadius;
    outerR = flower.petalOuterRadius;

    for (int j=0; j<flower.petalCount; j++)
    {
      angle = j * 2.0 * PI / petalCount;
      px = fx + cos(angle) * outerR;
      py = fy + sin(angle) * outerR;

      context.beginPath();
      context.arc(px, py, petalRadius, 0, TAU, false);
      context.fillStyle = flower.secondaryColour;
      context.fill();
    }
  }

  context.restore();
}

void _drawFps() {
  context.fillStyle = "#000000";
  context.fillText("FPS ${fps.round()}",10, 10);
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

  for (var flower in flowers) {
    x0 = flower.x;
    y0 = flower.y;

    distance = sqrt((x1-x0)*(x1-x0) + (y1-y0)*(y1-y0));

    if (distance <= flower.messageOuterRadius) {
      flower.lastPickedDistance = distance;
      flowersLastPicked.add(flower);
    }
  }

  num newPetalCount = 0;
  for (Flower flower in flowersLastPicked) {
    newPetalCount = flower.petalCount + 2;

    // odd numbers look better
    if (newPetalCount == 2) newPetalCount = 3;
    _updatePetalCount(flower, newPetalCount);
  }
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

  print ("$playAreaWidth $playAreaHeight $mainAreaX $mainAreaY $mainAreaX2 $mainAreaY2");
  playArea.width = playAreaWidth;
  playArea.height = playAreaHeight;
}

void _resizedWindow(e) {
  _resize(e.currentTarget.innerWidth, e.currentTarget.innerHeight);
}

void _restart() {
  flowers.clear();

  // Use 16 bit character codes as world seed
  seeds.clear();
  seeds.addAll(seed.codeUnits);

  _createPlayerFlower();
  flowers.add(playerFlower);
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

void _updateFlowerMessage(Flower flower, String message) {
  if (message == null) {
    flower.message = "";
    flower.messageLength = 0;
  } else {
    flower.message = message;
    flower.messageLength = message.length;
  }
}

void _updateFps(num time) {
  fps = 1000.0 / (time - renderTime);
  if (fpsAverage == null) fpsAverage = fps;
  fpsAverage = fps * 0.05 + fpsAverage * 0.95;
}

void _updatePetalCount(Flower flower, num count) {

  num petalCompensation = flower.petalRadius * 0.5;
  num flowerRadius = flower.radius + petalCompensation;
  flower.radius = flowerRadius;

  flower.petalCount = count;
  num petalRadiusTerm = (count == 0) ? 100 : count;
  num flowerPetalRadius = flowerRadius / (petalRadiusTerm * 0.25);
  flower.petalRadius = flowerPetalRadius;

  flower.petalOuterRadius = flowerRadius + (flowerPetalRadius * 0.40);

  if (flower.messageLength > 0) {
    flower.messageOuterRadius = (flowerRadius / (petalRadiusTerm * 0.25)) +
        (flower.radius + (flowerPetalRadius * 0.40)) +
        (flower.messageLength * 1.10);

    num px = (flowerPetalRadius * 0.75).round();
    if (px < 12) px = 12;

    flower.messageFont = "${px}px ${messageFontFamily}";
  } else {
    flower.messageOuterRadius = flower.petalOuterRadius;
  }
}

/// Represents flowers
/// Warn: Prob should keep this to transform stuff and break down message bloat
/// into other classes to prevent cache missing for doing transforms
class Flower {
  num x = 0.0;
  num y = 0.0;
  num radius = 0.0;
  num lastPickedDistance = 0.0;
  num petalCount = 0;
  num petalRadius = 0.0;
  num petalOuterRadius = 0.0;
  String primaryColour = "";
  String secondaryColour = "";
  String message = "";
  String messageFont = "";
  int messageLength = 0;
  num messageOuterRadius = 0.0;
  num messageRotation = PI;
}