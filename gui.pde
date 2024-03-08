import controlP5.*;
import processing.serial.*;

ControlP5 cp5;

Serial port;   
boolean portExists = false;
DropdownList portList;

Textarea messages;

Knob k1, k2;

PFont font1; // Declare font variable

int textAreaHeight, textAreaY;
int textAreaPadding = 20; // Internal padding for the TextArea
int cornerRad = 7;
float animationDuration = 0.3; // Animation duration in seconds

int rad = 125;

int switchWidth, switchHeight; // Dimensions of the toggle switch
boolean isClockwise = true;  
boolean isEnabled = true;
int sliderWidth, sliderHeight; // Dimensions of the slider


class xButton {
  float x, y, width, height, radius;
  String label;

  xButton(float x, float y, float width, float height, float radius, String label) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.radius = radius;
    this.label = label;
  }

  void draw() {
    if (isHovered()) {
      fill(25,125,225); // Set button background color when hovered
    } else {
      fill(50,150,255); // Set button background color
    }
    rect(x, y, width, height, radius); // Draw rounded rectangle
    
    fill(255); // Set text color
    textAlign(CENTER, CENTER); // Center the text
    textSize(16); // Set text size
    text(label, x + width/2, y + height/2); // Draw label in the center of the button
  }

  boolean isClicked(float mx, float my) {
    return mx > x && mx < x + width && my > y && my < y + height;
  }
  
  boolean isHovered() {
    return mouseX > this.x && mouseX < this.x + this.width && mouseY > this.y && mouseY < this.y + this.height;
  }
}

xButton homeButton, stepButton, jogButton;


class CustomSlider {
  float x, y;
  float width, height;
  float targetX;
  float animationStartTime;
  String a, b;
  boolean state; 
  
  CustomSlider(float x, float y, float width, float height, String a, String b) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.targetX = x;
    this.a = a;
    this.b = b;
  }
  
  void draw() {
    noStroke();
    fill(0);
    rect(x, y, width*2, height, cornerRad);
    
    fill(50, 150, 255);
    rect(targetX, y, width, height, cornerRad);
    
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(16);
    text(this.a, this.x + switchWidth/4, this.y + this.height/2);
    text(this.b, this.x + 3*switchWidth/4, this.y + this.height/2);
  }
   
  void update() {
    if (millis() - this.animationStartTime < animationDuration * 1000) {
      float t = (millis() - this.animationStartTime) / (animationDuration * 1000);    
      float easedValue = easeOutQuint(t);
      if (this.state) {
        this.targetX = this.x + sliderWidth - (int)(sliderWidth * easedValue);
      } else {
        this.targetX = this.x + (int)(((this.x+this.width) - this.x) * easedValue);
      }
    } 
  }
  
  void animate(boolean b) {
    this.state = b;
    this.animationStartTime = millis();
  }
  
  boolean isClicked(float mx, float my) {
    return mx > this.x && mx < this.x + switchWidth && my > this.y && my < this.y + this.height;
  }
}

CustomSlider dirSwitch, enaSwitch;


void setup() {
  size(1792, 1120);  
  cp5 = new ControlP5(this);
  
  font1 = createFont("Monospaced", 12); // Create font
  
  sliderWidth = 200;
  switchWidth = 400;
  
  homeButton = new xButton(1250, 100, 200, 50, cornerRad, "Go To Home");
  stepButton = new xButton(1250, 200, 200, 50, cornerRad, "Step");
  jogButton = new xButton(1250, 300, 200, 50, cornerRad, "Jog");
 
  enaSwitch = new CustomSlider(100, 100, sliderWidth, 50, "Enable", "Disable");
  dirSwitch = new CustomSlider(600, 100, sliderWidth, 50, "Clockwise", "Counterclockwise");
  
  textAreaHeight = height / 3; 
  textAreaY = height - textAreaHeight - textAreaPadding; 
    
  fill(0);
  rect(0, textAreaY, width, textAreaHeight);
  
  messages = cp5.addTextarea("Messages")
    .setPosition(textAreaPadding, textAreaY)
    .setSize(width/2, textAreaHeight - 150) // Full width with internal padding
    .setFont(font1)
    .setColor(color(255))
    .setColorBackground(color(0))
    .setColorForeground(color(200))
    .setLineHeight(20);
                      
  portList = cp5.addDropdownList("Select Serial Port")
    .setPosition(width/2, textAreaY+20)
    .setSize(width/2, textAreaHeight)
    .setBarHeight(30)
    .setItemHeight(30)
    .setColorBackground(color(0))
    .setColorActive(color(255))
    .setColorForeground(color(100))
    .setColorLabel(color(255))
    .setColorValueLabel(color(255)) // Set text color to white
    .setColorCaptionLabel(color(255));
    
  k1 = cp5.addKnob("speed1")
     .setCaptionLabel("Speed (deg/s)")
     .setRange(15,90)
     .setValue(45)
     .setPosition(100+switchWidth/2-rad, 300)
     .setRadius(rad)
     .setNumberOfTickMarks(5)
     .setTickMarkLength(5)
     .setTickMarkWeight(2)
     .snapToTickMarks(true)
     .setColorBackground(color(10)) // Set knob background color
     .setColorForeground(color(50,150,255)) // Set knob foreground color
     .setColorLabel(color(255)) // Set knob label color
     .setFont(font1);
     
  k2 = cp5.addKnob("angle1")
     .setCaptionLabel("Angle (deg)")
     .setRange(15,360)
     .setValue(90)
     .setPosition(600+switchWidth/2-rad, 300)
     .setRadius(rad)
     .setNumberOfTickMarks(23)
     .setTickMarkLength(5)
     .setTickMarkWeight(1)
     .snapToTickMarks(true)
     .setColorBackground(color(10)) // Set knob background color
     .setColorForeground(color(50,150,255)) // Set knob foreground color
     .setColorLabel(color(255)) // Set knob label color
     .setFont(font1);

     
  k1.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent event) {
      if (event.getAction() == ControlP5.ACTION_RELEASE) {
        float value = event.getController().getValue();
        sendCommand('S', (int)value);
      }
    }
  });
  
  k2.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent event) {
      if (event.getAction() == ControlP5.ACTION_RELEASE) {
        float value = event.getController().getValue();
        sendCommand('A', (int)value);
      }
    }
  });
    
  updatePortList();

}

void draw() {
  background(15,25,35);
  
  fill(0);
  rect(0, textAreaY, width, textAreaHeight);
  
  homeButton.draw();
  stepButton.draw();
  jogButton.draw();
  
  dirSwitch.draw();
  dirSwitch.update();
  
  enaSwitch.draw();
  enaSwitch.update();
}


void sendCommand(char command, int... parameters) {
  if (port != null && port.active()) { // Check if the port is open
    String message = "<" + command + ":";
    for (int param : parameters) {
      message += param + ",";
    }
    message = message.substring(0, message.length() - 1); // Remove the trailing comma
    message += ">";
    port.write(message + "\n"); // Send the message over serial
    displayErrorMessage(message);
  } else {
    displayErrorMessage("Error: Serial port is not open.");
  }
}



// Ease Out Quint function
float easeOutQuint(float t) {
  return 1 - pow(1 - t, 5);
}


void mouseClicked() {
  if (homeButton.isClicked(mouseX, mouseY)) {
    home();
  } else if (stepButton.isClicked(mouseX, mouseY)) {
    step();
  } else if (jogButton.isClicked(mouseX, mouseY)) {
    jog();
  } else if (dirSwitch.isClicked(mouseX, mouseY)) {
    direction();
  } else if (enaSwitch.isClicked(mouseX, mouseY)) {
    enable();
  } 
}





void direction() {
  isClockwise = !isClockwise;
  dirSwitch.animate(isClockwise);
  if (isClockwise) {
    sendCommand('D', 1);
  } else {
    sendCommand('D', 0);
  }
}


void enable() {
  isEnabled = !isEnabled;
  enaSwitch.animate(isEnabled);
  if (isEnabled) {
    sendCommand('E', 1);
  } else {
    sendCommand('E', 0);
  }
}





void controlEvent(ControlEvent theEvent) {
  if (theEvent.isFrom(portList)) {
    int selectedIndex = (int) theEvent.getValue();
    if (selectedIndex >= 0) {
      String selectedPort = portList.getItem((int)theEvent.getValue()).get("text").toString();
      connectToPort(selectedPort);
    }
  }
  
  if (theEvent.isController() && theEvent.getName().equals("Connect")) {
    int selectedIndex = (int) portList.getValue();
    String selectedPort = portList.getItem(selectedIndex).get("text").toString();
    connectToPort(selectedPort);
  }
}

void updatePortList() {
  portList.clear();
  String[] ports = Serial.list();
  for (int i = 0; i < ports.length; i++) {
    if (ports[i].startsWith("/dev/tty")) {
      portList.addItem(ports[i], i).setFont(font1);
    }
  }
}

void connectToPort(String portName) {
  try {
    port = new Serial(this, portName, 115200);
    portExists = true;
    displayErrorMessage("Connected to " + portName);
  } catch (Exception e) {
    displayErrorMessage("Error connecting to serial port: " + e.getMessage());
  }
}

void serialEvent(Serial port) {
  String serialData = port.readStringUntil('\n');
  if (serialData != null) {
    displaySerialMessage(serialData);
  }
}

void displayErrorMessage(String message) {
  println(message);
  messages.append(message + "\n");
  scrollToBottom();
}

void displaySerialMessage(String message) {
  println(message);
  messages.append(message + "\n");
  scrollToBottom();
}

void scrollToBottom() {
  messages.scroll(10000);
}


void home() {
  sendCommand('H');
}
void step() {
  sendCommand('I');
}
void jog() {
  sendCommand('X');
}
