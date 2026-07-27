#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <Adafruit_MQTT.h>
#include <Adafruit_MQTT_Client.h>


//  ------------------------------------------------------------------------

#define WLAN_SSID           "Test"
#define WLAN_PASS           "testtest"

#define AIO_SERVER          "io.adafruit.com"
#define AIO_SERVERPORT      1883
//  CHANGE THIS!
#define AIO_USERNAME         "your_aio_username"
#define AIO_KEY              "your_aio_key"

#define MQTT_TOPIC_ROOT         "/feeds/"
#define MQTT_TOPIC_HP           "hp"
#define MQTT_TOPIC_TEMPERATURE  "temp"
#define MQTT_TOPIC_ALARM        "alarm"

#define BLINK_ALARM   100


WiFiClient client;
Adafruit_MQTT_Client mqtt(&client, AIO_SERVER, AIO_SERVERPORT, AIO_USERNAME, AIO_KEY);

String selected_house="", selected_room="";
String human_presence="0", alarm="0";
//  ------------------------------------------------------------------------

void getCommands();
bool getHumanPresenceInput(String);
bool getTemperatureInput(String);
bool getHouseRoomNameInput(String);
String getSplittenValue(String, char, int);
String generateFeedKey(String, String, const char*);
void getAlarm();
void triggerAlarm();
void sendToMQTT(Adafruit_MQTT_Publish, String);
void blinkLED();
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
    getAlarm();
    triggerAlarm();
  }
}

//  ------------------------------------------------------------------------

void getCommands() {
  if (Serial.available()>0) {
    String input = Serial.readString();
    input.replace("\n","");
    //  WE ARLREADY GOT THE HOUSE AND ROOM NAME
    if (selected_house.length()>0 && selected_room.length()>0) {
      if (!getHumanPresenceInput(input) && !getTemperatureInput(input) && !getHouseRoomNameInput(input)) Serial.println("Invalid command");
    } else {
      if (!getHouseRoomNameInput(input)) {
        if (selected_house.length()==0) Serial.println("You must select a house");
        else if (selected_room.length()==0) Serial.println("You must select a room");
      }
    }
  }
}

//  GET HUMAN PRESENCE INPUT
bool getHumanPresenceInput(String input) {
  if (input.startsWith(String("HP=")) || input.startsWith(String("hp="))) {
    String key= generateFeedKey(selected_house, selected_room, MQTT_TOPIC_HP);
    Adafruit_MQTT_Publish publisher_hp= Adafruit_MQTT_Publish(&mqtt, key.c_str());
    
    String hp = getSplittenValue(input, '=', 1);
    if (hp.equals("1") || hp.equals("0")) {
      human_presence= hp;
      sendToMQTT(publisher_hp, hp);
      Serial.println("Selected Human Presence: " + hp);
      return true;
    }
    Serial.println("Invalid Presence");
    return false;
  } return false;
}
//  GET TEMPERATURE INPUT
bool getTemperatureInput(String input) {
  if (input.startsWith(String("TEMP=")) || input.startsWith(String("temp="))) {
    String key= generateFeedKey(selected_house, selected_room, MQTT_TOPIC_TEMPERATURE);
    Adafruit_MQTT_Publish publisher_temp= Adafruit_MQTT_Publish(&mqtt, key.c_str());

    String temp = getSplittenValue(input, '=', 1);
    if (temp.toFloat()==0) { Serial.println("Invalid Temperature"); return false; }
    
    sendToMQTT(publisher_temp, temp);
    Serial.println("Selected Temperature: " + temp);
    return true;
  } return false;
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


//  QoS=2 -> Message will be delivered exactly once, and then the client will be disconnected
void sendToMQTT(Adafruit_MQTT_Publish mqtt_topic, String message) {
  while (!mqtt_topic.publish(message.c_str())) { Serial.println("Message Publish failed!"); WIFI_setup(); connectMQTT(); }
  Serial.println(message+" Publish successfully!");
}

void getAlarm() {
  connectMQTT();
  String key= generateFeedKey(selected_house, selected_room, MQTT_TOPIC_ALARM);
  Adafruit_MQTT_Subscribe subscriber_alarm= Adafruit_MQTT_Subscribe(&mqtt, key.c_str());
  mqtt.subscribe(&subscriber_alarm);
  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(5000))) {
    if (subscription == &subscriber_alarm) {
      String data = String((char*)subscriber_alarm.lastread);
      alarm= data;
    }
  }
}

void triggerAlarm() {
  Serial.println("Alarm: "+alarm);
  Serial.println("HP: "+human_presence);
  if (alarm.equals("1") && human_presence.equals("1")) {
    Serial.println("ALARM TRIGGERED");
    blinkLED();
  }
}

void blinkLED() {
  digitalWrite(LED_BUILTIN, HIGH);
  delay(BLINK_ALARM);
  digitalWrite(LED_BUILTIN, LOW);
  delay(BLINK_ALARM);
}

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
