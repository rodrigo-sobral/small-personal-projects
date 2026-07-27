#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <Adafruit_MQTT.h>
#include <Adafruit_MQTT_Client.h>


//  ------------------------------------------------------------------------

#define WLAN_SSID         "Test"
#define WLAN_PASS         "testtest"

#define AIO_SERVER        "io.adafruit.com"
#define AIO_SERVERPORT   1883
//  CHANGE THIS!
#define AIO_USERNAME         "your_aio_username"
#define AIO_KEY              "your_aio_key"

#define MQTT_TOPIC_ROOT         "/feeds/"
#define MQTT_TOPIC_HP           "hp"
#define MQTT_TOPIC_TEMPERATURE  "temp"
#define MQTT_TOPIC_TEMP_CHANGES "changes"
#define MQTT_TOPIC_TEMP_LIMITS  "limits"

WiFiClient client;
Adafruit_MQTT_Client mqtt(&client, AIO_SERVER, AIO_SERVERPORT, AIO_USERNAME, AIO_KEY);


String selected_house="", selected_room="";

String MIN1= "", MAX1= "", MIN2= "", MAX2= "";
String temperature = "";
String heating= "0", cooling= "0";
String human_presence= "0";

//  ------------------------------------------------------------------------

void getCommands();
bool getHouseRoomNameInput(String);
String getSplittenValue(String, char, int);
String generateFeedKey(String, String, const char*);
void getTemperature();
void getHumanPresence();
void getTempLimits();
void getTempChanges();
void heat_coolRoom();
void sendTempMQTT(String);
void turnOnLED();
void turnOffLED();
void WIFI_setup();
void connectMQTT();

//  ------------------------------------------------------------------------

void setup() {
    Serial.begin(9600); delay(10);
    WIFI_setup();
    connectMQTT();
    pinMode(LED_BUILTIN,OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);
}

void loop() { 
  delay(100);
  getCommands();
  if (selected_house.length()>0 && selected_room.length()>0) {
    getTemperature();
    getHumanPresence();
    getTempChanges();
    getTempLimits();
    heat_coolRoom();
    Serial.println("MIN1: "+MIN1+" MAX1: "+MAX1+" MIN2: "+MIN2+" MAX2: "+MAX2);
    Serial.println("Temperature: "+temperature);
    Serial.println("Heating: "+heating+" Cooling: "+cooling);
    Serial.println("Human Presence: "+human_presence);
  }
}

//  ------------------------------------------------------------------------

void getCommands() {
  if (Serial.available()>0) {
    String input = Serial.readString();
    input.replace("\n","");
    //  WE ARLREADY GOT THE HOUSE AND ROOM NAME
    if (selected_house.length()>0 && selected_room.length()>0) {
      if (!getHouseRoomNameInput(input)) Serial.println("Invalid command");
    } else {
      if (!getHouseRoomNameInput(input)) {
        if (selected_house.length()==0) Serial.println("You must select a house");
        else if (selected_room.length()==0) Serial.println("You must select a room");
      }
    }
  }
}

//  GET HOUSE AND ROOM INPUT
bool getHouseRoomNameInput(String input) {
  if (input.startsWith(String("H=")) || input.startsWith(String("h="))) {
    selected_house = getSplittenValue(input, '=', 1);
    Serial.println("Selected House: " + selected_house);
    return true;
  } else if (input.startsWith(String("R=")) || input.startsWith(String("r="))) {
    selected_room = getSplittenValue(input, '=', 1);
    Serial.println("Selected Room: " + selected_room);
    return true;
  } return false;
}

//  GETS THE indexº ELEMENT FROM data, SPLITTEN BY THE seperator
String getSplittenValue(String data, char separator, int index) {
  int found = 0;
  int strIndex[] = {0, -1};
  int maxIndex = data.length()-1;

  for (int i=0; i<=maxIndex && found<=index; i++) {
    if(data.charAt(i)==separator || i==maxIndex) {
      found++;
      strIndex[0] = strIndex[1]+1;
      strIndex[1] = (i == maxIndex) ? i+1 : i;
    }
  }
  return found>index ? data.substring(strIndex[0], strIndex[1]) : "";
}

//  FORMAT STRING TO MQTT FEED KEY
String generateFeedKey(String house, String room, const char* feed) { 
  house.toLowerCase();
  room.toLowerCase();
  return String(AIO_USERNAME) + String(MQTT_TOPIC_ROOT) + house + String("-") + room + String("-") + String(feed);
}

//  ------------------------------------------------------------------------------------------------------------------------
//  SUBSCRIPTIONS
//  ------------------------------------------------------------------------------------------------------------------------

//  SUBSCRIBE TO MQTT TEMPERATURE TOPIC
void getTemperature() {
  connectMQTT();
  String key= generateFeedKey(selected_house, selected_room, MQTT_TOPIC_TEMPERATURE);
  Adafruit_MQTT_Subscribe subscriber_temp = Adafruit_MQTT_Subscribe(&mqtt, key.c_str());
  mqtt.subscribe(&subscriber_temp);

  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(5000))) {
    if (subscription == &subscriber_temp) {
      String data = String((char*)subscriber_temp.lastread);
      temperature = data;
    }
  }
}
//  SUBSCRIBE TO MQTT HUMAN PRESENCE TOPIC [0,1]
void getHumanPresence() {
  connectMQTT();
  String key= generateFeedKey(selected_house, selected_room, MQTT_TOPIC_HP);
  Adafruit_MQTT_Subscribe subscriber_hp = Adafruit_MQTT_Subscribe(&mqtt, key.c_str());
  mqtt.subscribe(&subscriber_hp);

  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(5000))) {
    if (subscription == &subscriber_hp) {
      String data = String((char*)subscriber_hp.lastread);
      if (data.equals("0") || data.equals("1")) human_presence = data;
    }
  }
}
//  SUBSCRIBE TO MQTT TEMPERATURE LIMITS TOPIC [MIN1, MAX1, MIN2, MAX2]
void getTempLimits() {
  connectMQTT();
  String key= generateFeedKey(selected_house, selected_room, MQTT_TOPIC_TEMP_LIMITS);
  Adafruit_MQTT_Subscribe subscriber_limits = Adafruit_MQTT_Subscribe(&mqtt, key.c_str());
  mqtt.subscribe(&subscriber_limits);

  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(5000))) {
    if (subscription == &subscriber_limits) {
      String data = String((char*)subscriber_limits.lastread);
      MIN1 = getSplittenValue(data, ':', 0);
      MAX1 = getSplittenValue(data, ':', 1);
      MIN2 = getSplittenValue(data, ':', 2);
      MAX2 = getSplittenValue(data, ':', 3);
    }
  }
}
//  SUBSCRIBE TO MQTT TEMPERATURE CHANGES TOPIC [HEATING, COOLING]
void getTempChanges() {
  connectMQTT();
  Serial.println("Checking Changes...");
  String key= generateFeedKey(selected_house, selected_room, MQTT_TOPIC_TEMP_CHANGES);
  Adafruit_MQTT_Subscribe subscriber_changes = Adafruit_MQTT_Subscribe(&mqtt, key.c_str());
  mqtt.subscribe(&subscriber_changes);
  
  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(5000))) {
    if (subscription == &subscriber_changes) {
      String data = String((char*)subscriber_changes.lastread);

      //  ------------------------------------------------------------------------
      //  MANNUAL STOP HEATING AND COOLING
      //  ------------------------------------------------------------------------
      String new_heating = getSplittenValue(data, ':', 0);
      if (heating.equals("0") && new_heating.equals("1")) {                 //  START HEATING
        Serial.println("Heating up the room");
        turnOnLED();
      } else if (heating.equals("1") && new_heating.equals("0")) {          //  STOP HEATING
        Serial.println("Temperature stabilized at " + temperature+"ºC");
        turnOffLED();
      }
      heating = new_heating;
      //  ------------------------------------------------------------------------
      String new_cooling = getSplittenValue(data, ':', 1);
      if (cooling.equals("0") && new_cooling.equals("1")) {                 //  START COOLING
        Serial.println("Cooling down the room");
        turnOnLED();
      }
      else if (cooling.equals("1") && new_cooling.equals("0")) {            //  STOP COOLING
        Serial.println("Temperature stabilized at " + temperature+"ºC");
        turnOffLED();
      }
      cooling = new_cooling;
    }
  }
}


void heat_coolRoom() {  
  String temp_limits[2];
  if (human_presence.equals("1")) { temp_limits[0]= MIN1; temp_limits[1]= MAX1; }
  else { temp_limits[0]= MIN2; temp_limits[1]= MAX2; }
  
  //  ------------------------------------------------------------------------
  //  AUTOMATICALLY AND INSTANT HEATING AND COOLING
  //  ------------------------------------------------------------------------
  if (temperature.toFloat() < temp_limits[0].toFloat()) { 
    turnOnLED();
    temperature= temp_limits[0]; 
    sendTempMQTT(temperature); 
    cooling = "0";
    Serial.println("Temperature stabilized at " + temperature+"ºC");
    turnOffLED();
  } else if (temperature.toFloat() > temp_limits[1].toFloat()) { 
    turnOnLED();
    temperature= temp_limits[1];
    sendTempMQTT(temperature);
    heating = "0";
    Serial.println("Temperature stabilized at " + temperature+"ºC");
    turnOffLED();
  } 
  //  ------------------------------------------------------------------------
  //  MANUALLY HEATING AND COOLING
  //  ------------------------------------------------------------------------
  else if (heating.equals("1") || cooling.equals("1")) {
    if (heating.equals("1")) temperature = String(temperature.toFloat() + 1);
    else if (cooling.equals("1")) temperature = String(temperature.toFloat() - 1);
    sendTempMQTT(temperature);
  } 
}


//  QoS=2 . Message will be delivered exactly once, and then the client will be disconnected
void sendTempMQTT(String message) {
  String key= generateFeedKey(selected_house, selected_room, MQTT_TOPIC_TEMPERATURE);
    Adafruit_MQTT_Publish publisher_temp = Adafruit_MQTT_Publish(&mqtt, key.c_str());
    while (!publisher_temp.publish(message.c_str())) { Serial.println("Message Publish failed!"); WIFI_setup(); connectMQTT(); }
    Serial.println(message+" Publish successfully!");
}

void turnOnLED() { digitalWrite(LED_BUILTIN, HIGH); }
void turnOffLED() { digitalWrite(LED_BUILTIN, LOW); }


//  ------------------------------------------------------------------------


void WIFI_setup() {
  if (WiFi.isConnected()) return;

  Serial.printf("\nConnecting to %s\n", WLAN_SSID);

  WiFi.begin(WLAN_SSID, WLAN_PASS);
  while (WiFi.status()!=WL_CONNECTED) { delay(500); Serial.print("."); }

  Serial.print("\nWiFi connected | IP address: ");
  Serial.println(WiFi.localIP());
}

//  connects to the network and then to the MQTT broker
void connectMQTT() {
  int8_t ret;
  if (mqtt.connected()) return;
  
  Serial.print("\nConnecting to MQTT...\n");

  uint8_t retries = 3;
  while ((ret = mqtt.connect()) != 0) { // connect will return 0 for connected
    Serial.println(mqtt.connectErrorString(ret));
    Serial.printf("Retry %d MQTT connection in 3 seconds...\n", retries);
    mqtt.disconnect();
    delay(3000);
    retries--;
    if (retries == 0) { Serial.println("Connection failed :("); return; }
  }
  Serial.println("MQTT Connected!");
}
