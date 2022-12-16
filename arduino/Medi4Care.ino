bool activeUltrasonic    = true;
bool activeAccelerometer = true;
bool activeBluetooth     = true;

/*
 * __________________________
 * |                        |
 * |   BLUETOOTH MODULE     |
 * |________________________|
 * 
 */
#include <SoftwareSerial.h>

char state = '0';
int pinRx = 5;
int pinTx = 4;

char side = 's';

SoftwareSerial BTserial(pinTx, pinRx);

/*
 * __________________________
 * |                        |
 * |    MPU9250 MODULE      |
 * |________________________|
 * 
 */

#include <Wire.h>
#include <MPU9250.h> // docs: https://github.com/hideakitai/MPU9250#i2c-address

/* 
 *  MPU9250 is a class and "IMU" is a object, we need to pass parameter to the object "IMU". wire is used for I2C communication, 
 *  second parameter is for I2C address, we left the ADO pin unconnected so its set to low, 0x68 is address, 
 *  if it was high then the address is 0x69 
*/
MPU9250 mpu;
// initial values
float ax0;
float ay0;
float az0;

/*
 * __________________________
 * |                        |
 * |   ULTRASONIC SENSOR    |
 * |________________________|
 * 
*/

#define HALF_SPEED_SOUND_MS 58.31
// if the duration of the signal (from its sending to its reception) is greater than this value, the signal is out of range from the sensor
#define OUT_OF_REACH 38000 
 
int pinTrigger_forward = 8;
int pinEcho_forward = 9; 
int pinTrigger_side = 12;
int pinEcho_side = 11;

static unsigned long tf  = 0;
static unsigned long dtf = 0;
static unsigned long ts  = 0;
static unsigned long dts = 0;

/*
 * __________________________
 * |                        |
 * |     PASSIVE BUZZER     |
 * |________________________|
 * 
*/

int pinPassiveBuzzer = 2;
int stateBuzzer = LOW;

// #define NOTE_DO4  262   
// #define NOTE_RE4  294
// #define NOTE_MI4  330
// #define NOTE_FA4  349
// #define NOTE_SOL4  392
// #define NOTE_LA4  440
// #define NOTE_SI4  494
// #define NOTE_DO5  523
// #define NOTE_RE5  587
// #define NOTE_MI5  659
#define NOTE_FA5  698
// #define NOTE_SOL5  784
#define NOTE_LA5 1500 //880
// #define NOTE_SI5  988

/*
 * __________________________
 * |                        |
 * |     ACTIVE BUZZER     |
 * |________________________|
 * 
*/

int pinVibrationMotorForward = 13;
int pinVibrationMotorSide = 7;

/*
 * __________________________
 * |                        |
 * |       FUNCTIONS        |
 * |________________________|
 * 
*/

void myTimer_forwardSensor (int ms){
  if(ms!=0){
    dtf = millis() - tf;
    if (dtf >= ms){
      // Change the buffer state
      /* eliminato
      if(stateBuzzer==LOW)
        stateBuzzer = HIGH;
      else
        stateBuzzer = LOW;  
        */
      stateBuzzer = LOW; // aggiunto
      tf = millis();
    }else stateBuzzer = HIGH; // aggiunto
  }
  else{
    stateBuzzer = HIGH;
  }

  digitalWrite(pinVibrationMotorForward, stateBuzzer);
  
  if (stateBuzzer == HIGH){
    tone(pinPassiveBuzzer, NOTE_FA5);
  }else {
    noTone(pinPassiveBuzzer);
  }
}

void myTimer_sideSensor (int ms){
  if(ms!=0){
    dts = millis() - ts;
    if (dts >= ms){
      // Change the buffer state
      /* eliminato
      if(stateBuzzer==LOW)
        stateBuzzer = HIGH;
      else
        stateBuzzer = LOW;  
        */
      stateBuzzer = LOW; // aggiunto
      ts = millis();
    }else stateBuzzer = HIGH; // aggiunto
  }
  else{
    stateBuzzer = HIGH;
  }

  digitalWrite(pinVibrationMotorSide, stateBuzzer);
  
  if (stateBuzzer == HIGH){
    tone(pinPassiveBuzzer, NOTE_LA5);
  }else {
    noTone(pinPassiveBuzzer);
  }
}

int getVibrationTime(int distance){
  // valore massimo e minimo: 30cm -> 1000ms (singolo); 100cm -> 20ms; (ripetuto)
  // equazione: y = 14x - 400;

  // eliminato
  //int vibrationTime = 14 * distance - 0;
  //return vibrationTime; // returns a value based on the parameter 

  if (distance > 60)
    return 700; //ms
  else if (distance > 20)
    return 400; //ms
  else
    return 0; //ms. The vibration is continuous
}

int nFallMessages = 0; // after 1500 fall messages it will be passed about 1 minute
int timesToCancelCount = 0;
bool isFall(float az) {
  // The state of falling under the influence of gravity is considered as free fall, where gravity is the only force acting on the body.
  // the new values ​​are updated approximately every 0.3 s
  float EBPercentage = 0.5; // 50% -> if the percentage is large, then the angle taken into account to calculate the fall approaches 90 °

  if (az0 - az0*EBPercentage > az){
    timesToCancelCount = 0;
    if(nFallMessages < 1500) nFallMessages++;
    else {
      nFallMessages = 0;
      return true; // the fall is verified
    }
  }else {
    // when timesToCancelCount equals 90 about 5 seconds have passed
    if (timesToCancelCount < 90) timesToCancelCount++;
    else {
      nFallMessages = 0;
      timesToCancelCount = 0;
    }
  }
  return false;
}

void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);    // Initialize serial communication
  
  BTserial.begin(9600);  // HC-06 default serial speed is 9600

  if(activeUltrasonic){
    pinMode(pinTrigger_forward, OUTPUT);
    pinMode(pinEcho_forward, INPUT);
    pinMode(pinTrigger_side, OUTPUT);
    pinMode(pinEcho_side, INPUT);
    pinMode(pinPassiveBuzzer, OUTPUT);
    pinMode(pinVibrationMotorForward, OUTPUT);
    pinMode(pinVibrationMotorSide, OUTPUT);
  }

  if(activeAccelerometer){
    Wire.begin();
    mpu.setup(0x68);  // change to your own address
    // calibrate anytime you want to
    mpu.calibrateAccelGyro();
    //mpu.calibrateMag();
    
    // Accelerometer data. These values are in meter per second square
    if (mpu.update()){
      ax0 = mpu.getAccX();
      ay0 = mpu.getAccY();
      az0 = mpu.getAccZ();
    }
  }
}

void loop() {
  // MPU9250 MODULE
  if(activeAccelerometer){
    if (mpu.update()){
      // Accelerometer data. These values are in meter per second square
      // float ax = mpu.getAccX();// float ay = mpu.getAccY();
      float az = mpu.getAccZ();
      // Gyroscope data. These values are in radians per second. //float gx = mpu.getGyroX(); //float gy = mpu.getGyroY(); //float gz = mpu.getGyroZ();
      // Magnetometer data. These values are in microtesla. //float mx = mpu.getMagX(); //float my = mpu.getMagY(); //float mz = mpu.getMagZ();
      // Temperature data. This value is in Celsius //float temp = mpu.getTemperature();
      
      if(isFall(az)) {
        BTserial.print("f");
      }
    }
  }
  
  // ULTRASONIC SENSOR
  long distance_forward;
  long distance_side;
  
  if(activeUltrasonic){
    // Generation of the forward sensor pulse
    digitalWrite(pinTrigger_forward, LOW);
    digitalWrite(pinTrigger_forward, HIGH);
    delayMicroseconds(10);
    digitalWrite(pinTrigger_forward, LOW);
    // Time calculation through the echo pin
    long duration_forward = pulseIn(pinEcho_forward, HIGH);
    distance_forward = duration_forward / HALF_SPEED_SOUND_MS; // the distance value is in cm
  
    // Generation of the side sensor pulse
    digitalWrite(pinTrigger_side, LOW);
    digitalWrite(pinTrigger_side, HIGH);
    delayMicroseconds(10);
    digitalWrite(pinTrigger_side, LOW);
    // Time calculation through the echo pin
    long duration_side = pulseIn(pinEcho_side, HIGH);
    distance_side = duration_side / HALF_SPEED_SOUND_MS; // the distance value is in cm
  
    Serial.print("Distance: forward=");
    Serial.print(distance_forward);
    Serial.print(" side=");
    Serial.println(distance_side);
    
    if(distance_side < distance_forward){
      if (duration_side < OUT_OF_REACH) {
        if (distance_side <= 60) myTimer_sideSensor(getVibrationTime(distance_side));
        else { 
          noTone(pinPassiveBuzzer);
          digitalWrite(pinVibrationMotorSide, LOW);
        }
      }else {
        noTone(pinPassiveBuzzer);
        digitalWrite(pinVibrationMotorSide, LOW);
      }
    }else{
      if (duration_forward < OUT_OF_REACH) {
        if (distance_forward <= 110) myTimer_forwardSensor(getVibrationTime(distance_forward));
        else {
          noTone(pinPassiveBuzzer);
          digitalWrite(pinVibrationMotorForward, LOW);
        }
      }else { 
        noTone(pinPassiveBuzzer);
        digitalWrite(pinVibrationMotorForward, LOW);
      }
    }
  }
  
  // BLUETOOTH MODULE
  if (activeBluetooth){
    if(BTserial.available() > 0){
      state = BTserial.read(); // state represents the value read by Arduino
    }
  
    if (side == 's'){
      BTserial.print(distance_forward);
      BTserial.print(",");
      BTserial.print(distance_side);
      BTserial.print(";");
    }
  
    // Do something in response to a bluetooth message received from Arduino
    switch (state){
      case 's':
        side = 's';
        break;
      case 'd':
        side = 'd';
        break;
       case 'a':
         if (side == 's'){
          //BTserial.print(distance_forward);
          //BTserial.print(";");
          //BTserial.print(distance_side);
          //BTserial.print(";");
         }
         break;
      default:
        break;
    }
  
    state = '0';
  }
}
