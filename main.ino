// pin definitions
#define VALVE_DIR_PIN      2
#define VALVE_STEP_PIN     3
#define VALVE_ENA_PIN      4
#define VALVE_PROX_PIN     5
#define CLOCKWISE         LOW
#define COUNTERCLOCKWISE  HIGH


// microstepping parameter [dip switches on driver to set]. This is the # of steps per full revolution.
int microsteps = 800;

// define a speed (revolutions per second)
float speed = 0.125; // e.g. 45 deg turn in one second

// The angle to rotate for a given rotation, to be updated by the controller
float angle = 90.0;

// gearbox ratio
int ratio = 10;

// number of steps per second
float steps_per_sec = microsteps * speed * ratio;

// define a step delay interval (each step requires a HIGH and a LOW, so divide by 2) [micros]
unsigned long step_delay = (unsigned long)(1.0 / steps_per_sec * 0.5 * 1e6);

// define a direction
int direction = 0;

// define a target
int target = 0;


// motor class
struct Motor {
  int dirPin;
  int stepPin;
  int enaPin;
  int proxPin;
  int dirState;
  int stepState;
  int enaState;
  unsigned long prevStep;     // micros
  unsigned long stepDelay;    // micros
  int stepCount;
  int target;
  int offset;                 // number of steps relative to the prox sensor for 'closed' - must be calibrated
};


// tune your homing procedure by changing these values until the valves are in a closed position
int valve_offset = 50;

// initialize motor objects
Motor Valve { VALVE_DIR_PIN, VALVE_STEP_PIN, VALVE_ENA_PIN, VALVE_PROX_PIN, LOW, LOW, LOW, 0, step_delay, 0, 0, valve_offset };




void setup() {

  // Serial port stuff
  Serial.begin(115200);

  // pinmode stuff
  pinMode(VALVE_DIR_PIN, OUTPUT);
  pinMode(VALVE_STEP_PIN, OUTPUT);
  pinMode(VALVE_ENA_PIN, OUTPUT);
  pinMode(VALVE_PROX_PIN, INPUT);



  // Enable the drivers so that we can run the homing function
  Valve.enaState = HIGH;
  digitalWrite(Valve.enaPin, Valve.enaState);

  
  // // Call valve homing function to ensure valves start in a known position.
  // valveHome(&Valve);


  // // Now that our valves are in a known position, pull the enable pins low in order to disable
  // // the motor drivers e.g. 'disarmed'.
  // Valve.enaState = LOW;
  // digitalWrite(Valve.enaPin, Valve.enaState);
}



void loop() {

  // check for new Serial data
  recvWithStartEndMarkers();     

  // call valve operate with each motor
  valveOperate(&Valve);
}



void valveOperate(Motor *m) {

  // check if motor is enabled
  if (m->enaState == HIGH) {

    // check to see if the motor position is different from it's target
    if (m->stepCount != m->target) {

      if (m->stepCount == microsteps && m->target > microsteps) {
        m->stepCount -= microsteps;
        m->target -= microsteps;
      } else if (m->stepCount == 0 && m->target < 0) {
        m->stepCount += microsteps;
        m->target += microsteps;
      }

      // update the motor's dirState and write to driver
      if (direction != m->dirState) {
        m->dirState = direction;
        digitalWrite(m->dirPin, m->dirState);
      }

      // check to see if motor is ready to move another step
      if (micros() - m->prevStep > m->stepDelay) {

        // increment the motor step
        m->stepState = (m->stepState) ? LOW : HIGH;  // toggle from high to low or vice versa

        // only increment when stepState is HIGH. If dir is 0, then it will multiply by
        // -1, thus decrementing stepCount, otherwise if dir is 1, then it will multiply
        // by 1, incrementing stepCount
        m->stepCount += (1 * m->stepState) * (2 * m->dirState - 1);

        digitalWrite(m->stepPin, m->stepState);

        // update prevStep
        m->prevStep = micros();
      }

    }

  }

}



void valveHome(Motor *m) {

  // not homed yet
  bool homed = false;

  // variable for proximity sensor reading
  int proxState = 0;

  // lets make sure we debounce our proximity sensor
  int proxDebounce = 0;

  // need to get 5 consecutive readings
  while (proxDebounce < 5) {

    // get reading from proximity sensor
    int prox = digitalRead(m->proxPin);

    // increment proxDebounce if we get consistent readings, otherwise start over
    if (prox == proxState) {
      proxDebounce++;
    } else {
      proxDebounce = 0;
    }

    // set proxState to the most recent reading
    proxState = prox;
  }


  // update the target, depending on the current proxState. This will automatically result in
  // either a clockwise or counterclockwise rotation 
  if (proxState) {
    m->target = -microsteps;
  } else {
    m->target = microsteps;
  }


  // keep going until homed!
  while (!homed) {

    // need to find the 'leading edge' of the proximity sensor in the clockwise direction, and
    // this is our "HOME" position. From there, we can move to a "CLOSED" position by
    // moving 'X' number of steps past this based on our manual calibration, which we define in
    // our motor's 'offset' parameter.

    valveOperate(m);

    // check to see if homed
    int homed = checkProx(proxState, m->proxPin);
  }

  // now that our valve is homed, move the valve to the closed position
  if (homed) {

    // let's zero out the stepCount 
    m->stepCount = 0;

    // and let's set the target to be the motor offset, and since the stepCount is zero,
    // the target will be greater so it should automatically rotate clockwise 
    m->target = m->offset;

    // keep going until we reach the target
    while (m->stepCount != m->target) {
      valveOperate(m);
    }

    // valve should now be in the 'CLOSED' position, so lets set the stepCount to 0
    m->stepCount = 0;

    // now we are ready to test!
    Serial.println("Homed!");
  }

}





int checkProx(int ps, int proxPin) {

  bool status = false;

  // if proximity sensor is now reading different from proxState
  if (digitalRead(proxPin) != ps) {

    // new debounce variable
    int debounce = 0;
    bool checking = true;

    // keep going until no longer checking
    while (checking) {

      // take new reading
      int prox = digitalRead(proxPin);

      // increment proxDebounce if we get consistent readings, otherwise start over
      if (prox == ps) {
        debounce++;

      } else {
        debounce = 0;
        checking = false;
      }

      // if we get 5 consecutive readings, then we can confirm!
      if (debounce == 5) {
        status = true;
        checking = false;
      }

    }

  }

  // returns false by default
  return status;
}


// void writeIntIntoEEPROM(int address, unsigned int number) { 
//   EEPROM.write(address, number >> 8);
//   EEPROM.write(address + 1, number & 0xFF);
// }

// unsigned int readIntFromEEPROM(int address) {
//   return (EEPROM.read(address) << 8) + EEPROM.read(address + 1);
// }


void recvWithStartEndMarkers() {
  char command;
  int parameter;
  bool newData = false;
  
  if (Serial.read() == '<') {
    command = Serial.read();

    if (Serial.read() == ':') {
      parameter = Serial.parseInt();
    }

    newData = true;
  }

  if (newData) {
    Serial.print(command);
    Serial.println(parameter);
  }
  
  switch (command) {
    case 'D':
      direction = parameter;
      Serial.println(direction);
      break;

    case 'I':
      Valve.target = Valve.stepCount + direction;
      Serial.println(Valve.target);
      break;

    case 'X':
      target = (int)((angle / 360.0) * microsteps * ratio);
      Valve.target = Valve.stepCount + target * direction;
      Serial.println(target);
      break;

    case 'A':
      angle = parameter;
      Serial.println(angle);
      break;

    case 'S':
      speed = parameter / 360.0;  
      steps_per_sec = microsteps * speed * ratio; // update number of steps per second
      Valve.stepDelay = (unsigned long)(1.0 / steps_per_sec * 0.5 * 1e6); // update step delay interval
      Serial.println(Valve.stepDelay);
      break;

    case 'H':
      valveHome(&Valve);
      break;

    default:
      break;
  }
}

