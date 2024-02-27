import datetime
import json
import os
import re
import time
from flask import Flask, request, jsonify
# from embedchain import App
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
import datetime
from dotenv import load_dotenv
from openai import OpenAI
from googleapiclient.errors import HttpError
import google.generativeai as genai

app = Flask(__name__)

 
# client = OpenAI(
#     api_key=os.environ.get("OPENAI_API_KEY")
# )


  
genai.configure(api_key=os.environ.get("GOOGLE_API_KEY"))



@app.post("/search")
async def handle_search():
    query = request.json.get("query")
    context=request.json.get("context")
    
    response=genai.GenerativeModel('gemini-1.0-pro').generate_content(f"""
                                                                  THE RESPONSE SHOULD BE IN JSON
                                                                  I'm your journal/notes keep, I will help you extract information from your journal/notes that is provided here {context}. THE answer should be short and very concise. You are very chill and cool. You assist them and counsel then of they ask you to do so. THE response SHOULD be ONLY a JSON with 'message': Your reply SHOULD be in MARKDOWN with lists, titles and others when needed. 
                                                                  This is the query {query}
                                                               """).text.replace("`", '').replace("json", "")
    response=json.loads(response)
    print(response)
    try:
        return jsonify({"message": response["message"]}), 200
    except Exception as e:
        print(e)
        return jsonify({"message": str(e)}), 500

    

@app.route("/listEvents", methods=["POST"])
def list_events():
    accessToken = request.json.get("accessToken")
    refreshToken = request.json.get("refreshToken")
   
    try:
        events = listGoogleCalendarEvents(accessToken, refreshToken)
        return jsonify({"success": True, "events": events}), 200
    except Exception as e:
        print(e)
        return jsonify({"success": False, "message": str(e)}), 500

def listGoogleCalendarEvents(accessToken: str, refreshToken: str):
    creds = Credentials(token=accessToken,
                        refresh_token=refreshToken,
                        token_uri=os.getenv('TOKEN_URI'),
                        client_id=os.getenv('CLIENT_ID'),
                        client_secret=os.getenv('CLIENT_SECRET'))
    # Build the Google Calendar service
    service = build('calendar', 'v3', credentials=creds)

    # Get today's date in the required format
    today = datetime.datetime.utcnow().date()
    timeMin = datetime.datetime.combine(today, datetime.time(0, 0)).isoformat() + 'Z'  # Start of today (in UTC)
    # timeMax = datetime.datetime.combine(today, datetime.time(23, 59, 59)).isoformat() + 'Z'  # End of today (in UTC)

    # Call the Calendar API to list the events for today
    response = service.events().list(calendarId='primary', timeMin=timeMin,singleEvents=True,
                                       orderBy='startTime' ).execute()
    events = response.get('items', [])
    extracted_events = []

    for event in events:
        # Extract the required fields from each event
        title = event.get('summary', 'No Title')
        id=event.get('id')
        description = event.get('description', '')
        location = event.get('location', '')
        start_date_time = event.get('start', {}).get('dateTime', '')
        end_date_time = event.get('end', {}).get('dateTime', '')
        time_zone = event.get('start', {}).get('timeZone', '')
        meeting_link = event.get('hangoutLink', '')
        attendees_list = event.get('attendees', [])
        status = event.get('status', '')
        
        # Assuming 'cancelled' status means the event is not completed,
        # otherwise, the event is considered completed.
        isCompleted = status != 'cancelled'

        
        # Extract email addresses of attendees
        attendees = [attendee.get('email') for attendee in attendees_list if 'email' in attendee]
        
        # Create a dictionary for the current event
        event_dict = {
            'title': title,
            'description': description,
            'location': location,
            'startDate': start_date_time,
            'endDate': end_date_time,
            'timeZone': time_zone,
            'meetingLink': meeting_link,
            'attendees': attendees,
            'id': id,
            'isCompleted': isCompleted
            
        }
        
        # Append the dictionary to the list of extracted events
        extracted_events.append(event_dict)
    print(extracted_events)

    return extracted_events

@app.route("/chat", methods=["POST"])
def chat():
    print("Dewdew")
    context= request.json.get("context")
    prompt=request.json.get("prompt")
    events= request.json.get("events")
    accessToken = request.json.get("accessToken")
    refreshToken = request.json.get("refreshToken")
    timeZone = request.json.get("timeZone")

    current_date = request.json.get("currentDate")

    system_prompt = f"""
    DONE ASK MULTIPLE 'MORE' questions, if the user fails to respond to the specifics after a single try, then just PICK the best time with your knowledge about the Users calendar.
    THE RESPONSE SHOULD ONLY BE A JSON. NO EXTRA TEXT
 You are a digital Personal Assistant, You are here to ensure your day runs as smoothly as possible, based on today's date, {current_date}

You are here to assist with your scheduling needs, including meetings (which will be online, including the meeting link in my response).

1. Editing Events ("EDIT"):
When the action is "EDIT", your response should include a summary of the changes made to the events and the updated events data. The JSON structure for an "EDIT" action looks like this:

 All THREE fields are REQURIED for the "EDIT" action
{{
  "message": "Summary of the changes you've made.  Answer to the question in a chill human like way",
  "events": [
    {{
      "startDate": "Start time of the event in ISO8601 format. MANDATORY.",
      "endDate": "End time of the event in ISO8601 format. MANDATORY",
      "title": "Brief description of the event.",
      "description": "Further details about the event (optional).",
      "isOnlineMeeting": true or false,
      "attendees": ["List of participants involved in the event (optional)."],
      "location": "Physical location of the event (optional).",
      "id": "ID of the event to be edited."
    }}
  ],
  "action": "EDIT"
}} 
 
2. Deleting Events ("DELETE"):
When the action is "DELETE", your response should include a summary of the deleted events. The JSON structure for a "DELETE" action looks like this:
IF THE USER ASKS TO CLEAR THE CALENDAR FOR TODAY OR THE USER ASKS TO DELETE ALL EVENTS, THEN DELETE ALL EVENTS FOR TODAY. Use {datetime.datetime.now()} to understand TODAY or other REALTIVE DATE.
All THREE fields are REQUIRED for the "DELETE" action
{{
  "message": "Summary of the events you've deleted.  Answer to the question in a chill human like way",
  "ids": ["ONLY THE List of IDs of the events that SHOULD BE deleted."],
  "action": "DELETE"
}}
 
3. Adding Events ("ADD"):
If the user asks to add a new event or reminder, you should ask for the necessary details.
When the action is "ADD", your response should include a summary of the added events. The JSON structure for an "ADD" action looks like this:
    
All THREE fields are REQUIRED for the "ADD" action
    {{
    "message": "Summary of the events you've added.  Answer to the question in a chill human like way",
    "events": [
        {{
        "startDate": "Start time of the event in ISO8601 format.",
        "endDate": "End time of the event in ISO8601 format.",
        "title": "Brief description of the event.",
        "description": "Further details about the event (optional).",
        "isOnlineMeeting": true or false,
        "attendees": ["List of participants involved in the event (optional)."],
        "location": "Physical location of the event (optional)."
        }}
    ],
    "action": "ADD"
    }}
 
4. General Chat ("GENERAL"):
When the action is "GENERAL", your response should include a summary of the general chat. The JSON structure for a "GENERAL" action looks like this:
If the user asks to summarize their day, the 'message' SHOULD ONLY be a MARKDOWN TEXT.
All THREE fields are REQUIRED for the "GENERAL" action
{{
  "message": Answer to the question in a chill human like way,
  "action": "GENERAL"
}}
 

5. Futhur Enquiries (MORE):
When the action is "MORE" you should ask more specifics about the user's query to schedule the event. If eveything is specified except the EMAIL, ASK for it. If the user missed the email o fthe attended for an online meeting ask him that, or if he missed the start date ask him that. Whatever you ask them it should ask be once(you will decide than based on the CONTEXT provided below), dont keep asking them more specifics. If you user fails to respond to the specifics after a single try, then just PICK the best time with your knowledge about the Users calendar. The JSON structure for a "MORE" action looks like this:
    
All THREE fields are REQUIRED for the "MORE" action
    {{
    "message": Ask for the necessary details,
    "action": "MORE"
    }}


You are here to help you make the most of your day. Let's get started! 🚀


- The context for our chat:
{context}

- Your current calendar:
{events}

- Your request:
{prompt}

Remember, I'll structure my responses in JSON for clarity and ease of use.
"""
   
#     chat_prompt= client.chat.completions.create(
#         model="gpt-3.5-turbo",
#         messages=[
#             {
#                 "role": "system",
#                 "content": system_prompt
#             },
#             {"role": "user", "content": prompt}
#         ],
#    )   

    chat_prompt= genai.GenerativeModel('gemini-1.0-pro').generate_content(system_prompt).text.replace("`", '').replace("json","")
    
   
    # print(chat_prompt.choices[0].message.content)
    # jsonData=json.loads(chat_prompt.choices[0].message.content.replace("`", '').replace("json",""))
    
    # print(jsonData)
    jsonData=json.loads(chat_prompt)
    print(jsonData)
    # return jsonify({"success": True, "message":jsonData["message"], "response": jsonData["message"]}), 200
    if(jsonData["action"]=="EDIT"):
        print("Edit event")
        edit_event = editGoogleCalendarEvent(accessToken, refreshToken, jsonData, timeZone)
        if edit_event:
            return jsonify({"success": True,"message":jsonData["message"], "response": jsonData["message"],"action":jsonData["action"],})
        else:
            return jsonify({"success": False, "response": jsonData})
    
    elif(jsonData["action"]=="DELETE"):
        print("Delete event")
        delete_event = deleteGoogleCalendarEvent(accessToken, refreshToken, jsonData,)
        if delete_event:
            return jsonify({"success": True,"message":jsonData["message"], "response": jsonData["message"],"action":jsonData["action"],})
        else:
            return jsonify({"success": False, "response": jsonData})
    elif(jsonData["action"]=="ADD"):
        print("Add event")
        add_event = create_google_calendar_events(jsonData, accessToken,refreshToken, timeZone)
        if add_event:
            return jsonify({"success": True,"message":jsonData["message"], "response": jsonData["message"],"action":jsonData["action"],})
        else:
            return jsonify({"success": False, "response": jsonData})
    elif (jsonData["action"]=="MORE"):
        print("More event")
        return jsonify({"success": True,"message":jsonData["message"], "response": jsonData["message"],"action":jsonData["action"],})
    elif(jsonData["action"]=="GENERAL"):
        print("General chat")
        return jsonify({"success": True,"message":jsonData["message"], "response": jsonData["message"],"action":jsonData["action"],})
    else:
       return jsonify({"success": True,"message":jsonData["message"], "response": jsonData["message"],"action":jsonData["action"],})
       
def validate_email(email):
    """Simple email format validation."""
    pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    return re.match(pattern, email)

def create_google_calendar_events(events, accessToken, refreshToken, timezone):
    creds = Credentials(token=accessToken,
                        refresh_token=refreshToken,
                        token_uri=os.getenv('TOKEN_URI'),
                        client_id=os.getenv('CLIENT_ID'),
                        client_secret=os.getenv('CLIENT_SECRET'))
    service = build('calendar', 'v3', credentials=creds)
    created_events_info = []

    if not isinstance(events["events"], list):
        return "The 'events' parameter should be a list of dictionaries."

    for event in events["events"]:
        if not isinstance(event, dict):
            return "Each event should be a dictionary."
        
        event_body = {
            'summary': event.get('title'),
            'location': event.get('location', ''),
            'description': event.get('description', ''),
            'start': {'dateTime': event.get('startDate'), 'timeZone': timezone},
            'end': {'dateTime': event.get('endDate'), 'timeZone': timezone},
            'reminders': {'useDefault': False, 'overrides': [{'method': 'email', 'minutes': 24 * 60}, {'method': 'popup', 'minutes': 10}]},
        }

        attendees = event.get('attendees', [])
        # Validate email format for each attendee
        valid_attendees = [attendee for attendee in attendees if validate_email(attendee)]
        if valid_attendees:
            event_body['attendees'] = [{'email': attendee} for attendee in valid_attendees]

        if event.get('isOnlineMeeting', False):
            event_body['conferenceData'] = {
                'createRequest': {'requestId': f"{int(datetime.datetime.now().timestamp())}", 'conferenceSolutionKey': {'type': 'hangoutsMeet'}}
            }          

        try:
            response = service.events().insert(calendarId='primary', body=event_body, conferenceDataVersion=1).execute()
            meeting_link = response.get('hangoutLink') or "No Meeting Link"
            created_events_info.append({'eventLink': response.get('htmlLink'), 'meetingLink': meeting_link})
        except HttpError as e:
            print(f"HttpError when creating event: {e}")
            return False  # Skip this event and continue with the next one
        except Exception as e:
            print(f"Error creating event: {e}")
            
            return False  # Skip this event and continue with the next one

    message = events.get('message', "Events created successfully.")
    # Append meeting links to the message if available
    for event_info in created_events_info:
        if event_info['meetingLink'] != "No Meeting Link":
            message += f"\nMeeting Link: {event_info['meetingLink']}"

    return {'message': message, 'eventsInfo': created_events_info}

def deleteGoogleCalendarEvent(accessToken: str, refreshToken: str, eventIds):
    creds = Credentials(token=accessToken,
                        refresh_token=refreshToken,
                        token_uri='https://oauth2.googleapis.com/token',
                        client_id=os.getenv('CLIENT_ID'),
                        client_secret=os.getenv('CLIENT_SECRET'))
    service = build('calendar', 'v3', credentials=creds)

    success = True
    for eventId in eventIds["ids"]:
        try:
            service.events().delete(calendarId='primary', eventId=eventId).execute()
        except Exception as e:
            
            print(f"Error deleting event {eventId}: {e}")
            return False
    return eventIds["message"]

def editGoogleCalendarEvent(accessToken: str, refreshToken: str, jsonData, timezone):
    creds = Credentials(token=accessToken,
                        refresh_token=refreshToken,
                        token_uri='https://oauth2.googleapis.com/token',
                        client_id=os.getenv('CLIENT_ID'),
                        client_secret=os.getenv('CLIENT_SECRET'))
    service = build('calendar', 'v3', credentials=creds)

    success = True
    for event in jsonData["events"]:
        # Ensure each event is a dictionary
        if not isinstance(event, dict):
            print("Each event should be a dictionary.")
            continue

        # Construct the event body
        event_body = {
            'summary': event.get('title'),
            'location': event.get('location'),
            'description': event.get('description'),
            'start': {'dateTime': event.get('startDate'), 'timeZone': timezone},
            'end': {'dateTime': event.get('endDate'), 'timeZone': timezone},
            'attendees': [{'email': attendee} for attendee in event.get('attendees', [])],
            'reminders': {'useDefault': False, 'overrides': [{'method': 'email', 'minutes': 24 * 60}, {'method': 'popup', 'minutes': 10}]},
        }

        if event.get('isOnlineMeeting', False):
            event_body['conferenceData'] = {
                'createRequest': {'requestId': f"{int(datetime.datetime.now().timestamp())}", 'conferenceSolutionKey': {'type': 'hangoutsMeet'}}
            }
        try:
            service.events().update(calendarId='primary', eventId=event['id'], body=event_body).execute()
        except Exception as e:
            print(f"Error editing event {event['id']}: {e}")
            return False
    return jsonData["message"]



@app.route("/todaysSummary", methods=["POST"])
def todaysSummary():
    calendar_data = request.json.get("calendar")
    current_date = request.json.get("currentDate")


    # Format the calendar data as a JSON string if it's not already a string
     # Construct the prompt to analyze the calendar and summarize today's events
    prompt_text = (
        
        f"Analyze the provided calendar data : {calendar_data}"
        f"summarize the events for the current date ({current_date}). "
        f"Give me the summary of the events for the {current_date}"
        "The summary should be friendly, casual"
        "Give them a heads up"
        "If there is a meeting, provide the meeting link"
        "Make it short and concise as possible. "

        "'should ONLY be a MARKDOWN TEXT"
        f"If no events are scheudled for {current_date}, then tell them to enjoy their free time today!"
    )

    # Call the AI model with the constructed prompt
    response = genai.GenerativeModel('gemini-1.0-pro').generate_content(prompt_text).text.replace("`", "").replace("json", "")
    print(response)


    # Provide the response
    if response:
        return jsonify({"success": True, "message": response, "response": response}), 200
    else:
        # Provide a default message if the AI fails to generate a summary
        return jsonify({"success": True, "message": "Enjoy your free time today!"}), 200

if __name__ == "__main__":
    app.run(port=os.getenv("PORT", default=8000), host="0.0.0.0", debug=True)
