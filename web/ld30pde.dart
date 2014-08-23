import 'dart:html';
import 'dart:math';

const num TAU = 2.0 * PI;
const num TO_RADIANS = PI / 180.0;

CanvasRenderingContext2D context;
List<Flower> flowers = new List<Flower>();
num fpsAverage;
bool isFpsShown = true;
bool isPaused = false;
num lastTimestamp;
num mainAreaX;
num mainAreaY;
num mainAreaX2;
num mainAreaY2;
CanvasElement playArea;
HtmlElement playAreaParent;
num playAreaHeight = window.innerHeight;//720;
num playAreaWidth = window.innerWidth;//1280;
num renderTime;

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
  playArea = querySelector("#playArea");
  playAreaParent = playArea.parent;
  context = playArea.getContext("2d");
  window.onResize.listen(_resizedWindow);
  
  _resize(window.innerWidth, window.innerHeight);
  
  _restart();
  
  window.requestAnimationFrame(_update);
}

void _draw(num frameTimestamp) {
  num time = new DateTime.now().millisecondsSinceEpoch;
  bool drawFps = isFpsShown && renderTime != null;
  
  context.fillStyle = backgroundColour;
  context.fillRect(0, 0, playAreaWidth, playAreaHeight);
  
  _drawFlowers();
  
  if (drawFps) _showFps(1000.0 / (time - renderTime));
  renderTime = time;
}

void _drawFlowers() {
  _drawFlowerPetals();
  
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

void _drawFlowerMessages() {
  
}

void _drawFlowerPetals() {
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
    petalRadius = r / (flower.petalCount * 0.25) ;
    outerR = r + (petalRadius * 0.40);

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
  num startCentreX = mainAreaX * 2.0;
  num startCentreY = mainAreaY * 2.0;
  num startRadius = 20.0;
  String startMessage = "Touch me...";
  
  flowers.add(new Flower()..x = startCentreX
    ..y = startCentreY
    ..radius = startRadius
    ..primaryColour = allColours[9]
    ..secondaryColour = allColours[8]
    ..message = startMessage);
}

void _showFps(num fps) {
  if (fpsAverage == null) fpsAverage = fps;
  fpsAverage = fps * 0.05 + fpsAverage * 0.95;
  context.fillStyle = "#000000";
  context.fillText("FPS ${fps.round()}",10, 10);
}

void _update(num frameTimestamp) {
  window.requestAnimationFrame(_update);
  
  if (lastTimestamp == null) lastTimestamp = frameTimestamp;
  else if (frameTimestamp != lastTimestamp) {
    _draw(frameTimestamp);
  }
}

class Flower {
  num x;
  num y;
  num radius;
  num petalCount = 0;
  String primaryColour;
  String secondaryColour;
  String message;
}