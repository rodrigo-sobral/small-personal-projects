from flask import Flask, render_template, redirect, url_for, request
from Adafruit_IO import Client, Feed, Block, Layout
from os import environ
from time import sleep
from flask.templating import render_template_string

#   -----------------------------------------------------------------------------------------------------------------------
#   MQTT
#   -----------------------------------------------------------------------------------------------------------------------

#   --------------------------------------
#   TOPICS
#  CHANGE THIS!
ADAFRUIT_IO_USERNAME = 'your_aio_username'
ADAFRUIT_IO_KEY = 'your_aio_key'

MQTT_DASHBOARD_KEY = 'debugger'
MQTT_GROUP_KEY = 'default'
MQTT_TOPIC_ALARM = 'alarm'
MQTT_TOPIC_HP = 'hp'
MQTT_TOPIC_TEMPERATURE = 'temp'
MQTT_TOPIC_CHANGES = 'changes'
MQTT_TOPIC_LIMITS = 'limits'

#   ----------------------------
#   FUNCS

#   SEND VALUE TO MQTT TOPIC
def sendMessageTo(client: Client, topic:str, value:str): client.send_data(topic, value)
#   GET value FROM MQTT topic, RETURN error_case IF ERROR
def getMessageFrom(client: Client, topic:str, error_case=None): 
    try: return client.receive(topic).value
    except: return error_case

#   GET ALL FEEDS FROM MQTT IN A FORMAT house_name-room_name-data_name
def getHousesRooms():
    global client, houses
    feed_names= [feed.__getitem__(0) for feed in client.feeds()]
    for feed_name in feed_names if feed_names else []:
        house_name, room_name, data = feed_name.split('-')[0], feed_name.split('-')[1], feed_name.split('-')[2]
        if house_name not in houses: houses[house_name] = {}
        if room_name not in houses[house_name]: houses[house_name][room_name] = {}
        houses[house_name][room_name][data] = getMessageFrom(client, feed_name.lower(), '0')

#   CREATE FEEDS OF ONE ROOM IN A FORMAT house_name-room_name-data_name
def createRoomTopics(house:str, room:str, data:dict) -> None:
    global client
    response_keys= []
    #   Create all feeds of the room
    for data_topic in data:
        feed_name= house + '-' + room + '-' + data_topic
        response= client.create_feed(Feed(name=feed_name, key=feed_name))
        response_keys.append(response.key)

    #   Create a New Debugger to the new Room
    stream = Block(name=house + '-' + room + ' Debugger',
        visual_type = 'stream',
        properties = { "fontSize": "12", "fontColor": "#63de00", "showGroupName": "no"},
        block_feeds = list([{"group_id": MQTT_GROUP_KEY, "feed_id": feed_key } for feed_key in response_keys]))
    stream = client.create_block(MQTT_DASHBOARD_KEY, stream)

    #   Update Layout to the new Debugger
    client.update_layout(MQTT_DASHBOARD_KEY, Layout(lg = [{'x': 0, 'y': 0, 'w':  7, 'h': 4, 'i': str(stream.id)}]))

    #   Send the default values to the new Room Topics
    for data_topic, key in zip(data, response_keys):
        client.send_data(key, data[data_topic])
        sleep(3)
    
#   CONVERTS A FEED NAME TO A FEED KEY, TURNING THE STRING TO LOWERCASE
def getFeedKeyFromName(selected_data:str) -> str: 
    global selected_house, selected_room
    return selected_house.lower() + '-' + selected_room.lower() + '-' + selected_data.lower()

#   DELETES SPECIAL AND NOT ACCEPTABLE CHARACTERS BY MQTT
def sanitizeString(string:str) -> str: 
    return string.replace(' ', '').replace('-', '').replace('_', '').replace('.', '').replace('/', '').replace('\\', '').replace('*', '').replace('?', '').replace('"', '').replace('<', '').replace('>', '').replace('|', '').replace('\'', '').replace('`', '').replace(',' ,'')

#   ----------------------------
#   CONTENTS
client = Client(ADAFRUIT_IO_USERNAME, ADAFRUIT_IO_KEY)
houses= {}
selected_house, selected_room= '', ''

#   -----------------------------------------------------------------------------------------------------------------------
#   INDEX.html
#   -----------------------------------------------------------------------------------------------------------------------

app = Flask(__name__)
app.secret_key = 'secret'
environ['WERKZEUG_RUN_MAIN'] = 'true'

@app.route('/')
def home():
    getHousesRooms()
    return render_template('index.html', 
        available_houses = houses, 
        available_rooms = houses[selected_house] if selected_house!='' else [], 
        selected_house = selected_house, 
        selected_room = selected_room)

@app.route('/addNewHouse', methods=['POST'])
def addNewHouse():
    house_name = sanitizeString(request.form.get('house_name')) if request.form.get('house_name') else None
    if house_name and house_name not in houses: 
        houses[house_name] = {}
        return redirect(url_for('home'))
    return render_template_string('<h1>❌ ERROR ❌</h1><br><h2>Invalid House Name</h2><br><form action="/"><button type="submit">Home</button></form>'), 400
    
@app.route('/addNewRoom', methods=['POST'])
def addNewRoom():
    global selected_house
    #   Get the house name
    if selected_house=='':
        return render_template_string('<h1>❌ ERROR ❌</h1><br><h2>Select a House</h2><br><form action="/"><button type="submit">Home</button></form>'), 400
    room_name = sanitizeString(request.form.get('room_name')) if request.form.get('room_name') else None
    #   Check if the room name is valid
    if room_name and room_name not in houses[selected_house]:
        houses[selected_house][room_name] = {
            MQTT_TOPIC_ALARM: '0',
            MQTT_TOPIC_HP: '0',
            MQTT_TOPIC_TEMPERATURE: '0',
            MQTT_TOPIC_CHANGES: '0:0',
            MQTT_TOPIC_LIMITS: '0:0:0:0'
        }
        #   Create the new Room Topics
        createRoomTopics(selected_house, room_name, houses[selected_house][room_name])
        return redirect(url_for('home'))
    return render_template_string('<h1>❌ ERROR ❌</h1><br><h2>Invalid Room Name</h2><br><form action="/"><button type="submit">Home</button></form>'), 400

@app.route('/selectHouse', methods=['POST'])
def selectHouse():
    global selected_house
    selected_house= request.form.getlist('available_houses')[0]
    return redirect(url_for('home'))

@app.route('/selectRoom', methods=['POST'])
def selectRoom():
    global selected_room
    selected_room= request.form.getlist('available_rooms')[0]
    return redirect(url_for('home'))

@app.route('/manageRoom', methods=['GET'])
def manageRoom():
    #   Redirect to the new web page with the selected room
    if selected_house!='' and selected_room!='':  return redirect(url_for('roomManagement'))
    return render_template_string('<h1>❌ ERROR ❌</h1><br><h2>Select a House and a Room to Manage</h2><br><form action="/"><button type="submit">Home</button></form>'), 400

#   -----------------------------------------------------------------------------------------------------------------------
#   ROOMS MANAGEMENT
#   -----------------------------------------------------------------------------------------------------------------------

@app.route('/roomManagement', methods=['GET'])
def roomManagement():
    global client, houses, selected_house, selected_room
    #   Get all the data from the selected room
    getHousesRooms()
    if not selected_house and not selected_room:
        return render_template_string('<h1>❌ ERROR ❌</h1><br><h2>House or Room Not Found</h2><br><form action="/"><button type="submit">Home</button></form>'), 404
    data= houses[selected_house][selected_room]
    return render_template('room.html', 
            house= selected_house,
            room= selected_room,
            temperature=data[MQTT_TOPIC_TEMPERATURE], 
            human_presence=data[MQTT_TOPIC_HP], 
            alarm=data[MQTT_TOPIC_ALARM], 
            heating=data[MQTT_TOPIC_CHANGES].split(':')[0], 
            cooling=data[MQTT_TOPIC_CHANGES].split(':')[1], 
            min1=data[MQTT_TOPIC_LIMITS].split(':')[0],
            max1=data[MQTT_TOPIC_LIMITS].split(':')[1], 
            min2=data[MQTT_TOPIC_LIMITS].split(':')[2],
            max2=data[MQTT_TOPIC_LIMITS].split(':')[3])

@app.route('/submitData', methods=['POST'])
def submitData(): 
    global client, houses, selected_house, selected_room
    #   Get alarm from form
    new_alarm = '1' if request.form.get('alarm')=='on' else '0'

    #   Cannot set the alarm on if the human presence is also on
    if new_alarm=='1' and houses[selected_house][selected_room][MQTT_TOPIC_HP]=='1': 
        return render_template_string('<h1>❌ ERROR ❌</h1><br><h2>You cannot set the alarm with people in the room</h2><br><form action="/"><button type="submit">Home</button></form>'), 400
        
    #   Submit Alarm only if it is different from the current one
    alarm = houses[selected_house][selected_room][MQTT_TOPIC_ALARM]
    if alarm[0]!=new_alarm:
        houses[selected_house][selected_room][MQTT_TOPIC_ALARM]= new_alarm
        sendMessageTo(client, getFeedKeyFromName(MQTT_TOPIC_ALARM), houses[selected_house][selected_room][MQTT_TOPIC_ALARM])
        
    #   Get heating/cooling from form and send it to the broker
    new_changes = request.form.getlist('changes')[0]
    if new_changes!=houses[selected_house][selected_room][MQTT_TOPIC_CHANGES]:
        houses[selected_house][selected_room][MQTT_TOPIC_CHANGES]= new_changes
        sendMessageTo(client, getFeedKeyFromName(MQTT_TOPIC_CHANGES), new_changes)
        
    #   Get limits from form
    new_min1, new_max1 = request.form.get('min1'), request.form.get('max1')
    new_min2, new_max2 = request.form.get('min2'), request.form.get('max2')
    #   Check if the limits are valid
    if float(new_min1)>float(new_max1) or float(new_min2)>float(new_max2):
        return render_template_string('<h1>❌ ERROR ❌</h1><br><h2>Maximum temperature must be greater than Minimum</h2><br><form action="/"><button type="submit">Home</button></form>'), 400
    new_limits= new_min1+':'+new_max1+':'+new_min2+':'+new_max2

    #   Submit Limits only if they are different from the current ones
    if new_limits!=houses[selected_house][selected_room][MQTT_TOPIC_LIMITS]:
        houses[selected_house][selected_room][MQTT_TOPIC_LIMITS]= new_limits
        sendMessageTo(client, getFeedKeyFromName(MQTT_TOPIC_LIMITS), new_limits)

    return redirect(url_for('roomManagement'))


#   ----------------------------
#   MAIN
if __name__ == '__main__': app.run('0.0.0.0', 8080, debug=False)
