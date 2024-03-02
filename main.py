import datetime
import json
import os
import re
import time
from flask import Flask, request, jsonify
from httpx import HTTPError, Timeout

# from embedchain import App
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
import datetime
from dotenv import load_dotenv
import httpx
from openai import OpenAI
from embedchain import App as embedchainApp

from vertexai.preview.generative_models import (
    Content,
    FunctionDeclaration,
    GenerativeModel,
    Part,
    Tool,
)


app = Flask(__name__)
os.environ["GOOGLE_API_KEY"] = os.environ.get("GOOGLE_API_KEY")

config = {
    "llm": {
        "provider": "google",
        "config": {
            "model": "gemini-pro",
            "max_tokens": 1000,
            "temperature": 0.5,
            "top_p": 1,
            "stream": False,
        },
    },
    "embedder": {
        "provider": "google",
        "config": {
            "model": "models/embedding-001",
            "task_type": "retrieval_document",
            "title": "Embeddings for Embedchain",
        },
    },
}
ecApp = embedchainApp.from_config(config=config)

client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))


@app.post("/add")
def handle_add():
    userId = request.json.get("userId")
    id = request.json.get("id")
    title = request.json.get("title")
    content = request.json.get("content")

    ids = ecApp.db.get()

    doc_hash = None
    for meta_data in ids["metadatas"]:
        if "userId" in meta_data and "noteId" in meta_data:
            if meta_data["userId"] == userId and meta_data["noteId"] == id:
                doc_hash = meta_data["hash"]
                break

    if doc_hash:
        ecApp.delete(doc_hash)

    ecApp.add(
        f"""
              {title}
              
              {content}""",
        metadata={"userId": userId, "noteId": id},
    )
    return jsonify({"message": "Note added successfully"}), 200


@app.post("/search")
def handle_search():
    query = request.json.get("query")
    userId = request.json.get("userId")
    response = ecApp.query(query, where={"userId": userId})
    print(response)
    try:
        return jsonify({"message": response}), 200
    except Exception as e:
        print(e)
        return jsonify({"message": str(e)}), 500


@app.route("/listEvents", methods=["POST"])
def list_events():
    accessToken = request.json.get("accessToken")
    refreshToken = request.json.get("refreshToken")
    userId = request.json.get("userId")

    try:
        events = listGoogleCalendarEvents(accessToken, refreshToken)
        ids = ecApp.db.get()

        doc_hash = None
        for meta_data in ids["metadatas"]:
            if "userId" in meta_data and "type" in meta_data:
                if meta_data["userId"] == userId and meta_data["type"] == "events":
                    doc_hash = meta_data.get(
                        "hash"
                    )  # Using .get() as a safer alternative
                    break

        if doc_hash:
            ecApp.delete(doc_hash)

        ecApp.add(str(events), metadata={"userId": refreshToken, "type": "events"})
        print
        (ecApp.db.get())
        return jsonify({"success": True, "events": events}), 200
    except Exception as e:
        print(e)
        return jsonify({"success": False, "message": str(e)}), 500


def listGoogleCalendarEvents(accessToken: str, refreshToken: str):
    creds = Credentials(
        token=accessToken,
        refresh_token=refreshToken,
        token_uri=os.getenv("TOKEN_URI"),
        client_id=os.getenv("CLIENT_ID"),
        client_secret=os.getenv("CLIENT_SECRET"),
        # Ensure you include the appropriate scopes required for your operations
        scopes=["https://www.googleapis.com/auth/calendar"],
    )

    service = build("calendar", "v3", credentials=creds)

    today = datetime.datetime.utcnow().date()
    timeMin = (
        datetime.datetime.combine(today, datetime.time(0, 0)).isoformat() + "Z"
    )  # Start of today (in UTC)

    response = (
        service.events()
        .list(
            calendarId="primary",
            timeMin=timeMin,
            singleEvents=False,  # Set to True to order by startTime
            # orderBy="startTime",  # Now valid because singleEvents is True
        )
        .execute()
    )

    events = response.get("items", [])
    extracted_events = []

    for event in events:
        # Extract the required fields from each event
        title = event.get("summary", "No Title")
        id = event.get("id")
        description = event.get("description", "")
        location = event.get("location", "")
        start_date_time = event.get("start", {}).get("dateTime", "")
        end_date_time = event.get("end", {}).get("dateTime", "")
        time_zone = event.get("start", {}).get("timeZone", "")
        meeting_link = event.get("hangoutLink", "")
        attendees_list = event.get("attendees", [])
        status = event.get("status", "")

        # Assuming 'cancelled' status means the event is not completed,
        # otherwise, the event is considered completed.
        isCompleted = status != "cancelled"

        # Extract email addresses of attendees
        attendees = [
            attendee.get("email") for attendee in attendees_list if "email" in attendee
        ]

        # Create a dictionary for the current event
        event_dict = {
            "title": title,
            "description": description,
            "location": location,
            "startDate": start_date_time,
            "endDate": end_date_time,
            "timeZone": time_zone,
            "meetingLink": meeting_link,
            "attendees": attendees,
            "id": id,
            "isCompleted": isCompleted,
        }

        # Append the dictionary to the list of extracted events
        extracted_events.append(event_dict)
    print(extracted_events)

    return extracted_events


@app.route("/", methods=["GET"])
def index():
    return jsonify({"message": ecApp.db.get()}), 200


@app.route("/chat", methods=["POST"])
async def chat():
    print("Dewdew")
    context = request.json.get("context")
    prompt = request.json.get("prompt")
    events = request.json.get("events")
    accessToken = request.json.get("accessToken")
    refreshToken = request.json.get("refreshToken")
    timeZone = request.json.get("timeZone")
    userId = request.json.get("userId")

    current_date = request.json.get("currentDate")
    print(events)
    print(prompt)
    print(context)
    print(current_date)

    jsonData = ecApp.query(
        f"""
    Respond with JSON structure based on user request. For "EDIT", "DELETE", and "ADD" actions, include required fields in specified order. Ask for missing details with "MORE". Summarize day with "GENERAL". Use human readable date formats in messages. Structure responses as clear JSON.
1. Editing Events ("EDIT"):
{{
  "message": "Summary of the changes you've made.  Answer to the question in a chill human like way",
  "events": [
    {{
      "startDate": "Start time of the event in ISO8601 format. MANDATORY.",
      "endDate": "End time of the event in ISO8601 format. MANDATORY",
      "title": "Brief description of the event.",
      "description": "Further details about the event (optional).",
      "isOnlineMeeting": True or False,
      "attendees": ["List of participants involved in the event (optional)."],
      "location": "Physical location of the event (optional).",
      "id": "ID of the event to be edited."
    }}
  ],
  "action": "EDIT"
}} 
2. Deleting Events ("DELETE"):
'ids' field is REQUIRED for the "DELETE" action. The ids field should contain the list of IDs of the events that should be deleted.
{{
  "message": "Summary of the events you've deleted.  Answer to the question in a chill human like way",
  "ids": ["ONLY THE List of IDs of the events that SHOULD BE deleted."],
  "action": "DELETE"
}}
3. Adding Events ("ADD"): 
startDate should only be added to the future from the current date
    {{
    "message": "Summary of the changes you've made. The answer should be relavant to the 'message'. Answer to the question in a chill human like way",
    "events": [
        {{
        "startDate": "Start time of the event in ISO8601 format.",
        "endDate": "End time of the event in ISO8601 format.",
        "title": "Brief description of the event.",
        "description": "Further details about the event (optional).",
        "isOnlineMeeting": True or False,
        "attendees": ["List of participants involved in the event (optional)."],
        "location": "Physical location of the event (optional)."
        }}
    ],
    "action": "ADD"
    }}
4. General Chat ("GENERAL"):
If asked for the meeeing link, provide the relavant meeting link. The link should contain http.
{{
  "message": Answer to the question in a chill human like way,
  "action": "GENERAL"
}}
5. Futhur Enquiries (MORE):
    {{
    "message": Ask for the necessary details,
    "action": "MORE"
    }}
- The context for our chat:
{context}
-current date is in ISO8601 format: {current_date}
-The calendar events
{events}
- your prompt 
{prompt}
If the action is DELETE, the ids field should contain the list of IDs of the events that should be deleted.
If the meeting is online leave the location field empty and set the isOnlineMeeting to True.
""",
        where={"userId": userId, "type": "events"},
    )

    print(jsonData)
    jsonData = json.loads(jsonData.replace("True", "true").replace("False", "false"))
    # return jsonify({"success": True, "message":jsonData["message"], "response": jsonData["message"]}), 200
    if jsonData["action"] == "EDIT":
        print("Edit event")
        edit_event = editGoogleCalendarEvent(
            accessToken, refreshToken, jsonData, timeZone
        )
        if edit_event:
            return jsonify(
                {
                    "success": True,
                    "message": jsonData["message"],
                    "response": jsonData["message"],
                    "action": jsonData["action"],
                }
            )
        else:
            return jsonify({"success": False, "response": jsonData})

    elif jsonData["action"] == "DELETE":
        print("Delete event")
        delete_event = deleteGoogleCalendarEvent(
            accessToken,
            refreshToken,
            jsonData,
        )
        if delete_event:
            return jsonify(
                {
                    "success": True,
                    "message": jsonData["message"],
                    "response": jsonData["message"],
                    "action": jsonData["action"],
                }
            )
        else:
            return jsonify({"success": False, "response": jsonData})
    elif jsonData["action"] == "ADD":

        add_event = create_google_calendar_events(
            jsonData, accessToken, refreshToken, timeZone
        )
        if add_event:
            return jsonify(
                {
                    "success": True,
                    "message": jsonData["message"],
                    "response": jsonData["message"],
                    "action": jsonData["action"],
                }
            )
        else:
            return jsonify({"success": False, "response": jsonData})
    elif jsonData["action"] == "MORE":
        print("More event")
        return jsonify(
            {
                "success": True,
                "message": jsonData["message"],
                "response": jsonData["message"],
                "action": jsonData["action"],
            }
        )
    elif jsonData["action"] == "GENERAL":
        print("General chat")
        return jsonify(
            {
                "success": True,
                "message": jsonData["message"],
                "response": jsonData["message"],
                "action": jsonData["action"],
            }
        )
    else:
        return jsonify(
            {
                "success": True,
                "message": jsonData["message"],
                "response": jsonData["message"],
                "action": jsonData["action"],
            }
        )


def validate_email(email):
    """Simple email format validation."""
    pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    return re.match(pattern, email)


def create_google_calendar_events(events, accessToken, refreshToken, timezone):
    print("Add event")
    print(accessToken)
    creds = Credentials(
        token=accessToken,
        refresh_token=refreshToken,
        token_uri=os.getenv("TOKEN_URI"),
        client_id=os.getenv("CLIENT_ID"),
        client_secret=os.getenv("CLIENT_SECRET"),
        scopes=["https://www.googleapis.com/auth/calendar"],
    )
    service = build("calendar", "v3", credentials=creds)
    created_events_info = []

    if not isinstance(events["events"], list):
        return "The 'events' parameter should be a list of dictionaries."

    for event in events["events"]:
        if not isinstance(event, dict):
            return "Each event should be a dictionary."

        event_body = {
            "summary": event.get("title"),
            "location": event.get("location", ""),
            "description": event.get("description", ""),
            "start": {
                "dateTime": event.get("startDate").replace("Z", ""),
                "timeZone": timezone,
            },
            "end": {
                "dateTime": event.get("endDate").replace("Z", ""),
                "timeZone": timezone,
            },
            "reminders": {
                "useDefault": False,
                "overrides": [
                    {"method": "email", "minutes": 24 * 60},
                    {"method": "popup", "minutes": 10},
                ],
            },
        }

        attendees = event.get("attendees", [])
        # Validate email format for each attendee
        valid_attendees = [
            attendee for attendee in attendees if validate_email(attendee)
        ]
        if valid_attendees:
            event_body["attendees"] = [
                {"email": attendee} for attendee in valid_attendees
            ]

        if event.get("isOnlineMeeting", False):
            event_body["conferenceData"] = {
                "createRequest": {
                    "requestId": f"{int(datetime.datetime.now().timestamp())}",
                    "conferenceSolutionKey": {"type": "hangoutsMeet"},
                }
            }

        try:
            response = (
                service.events()
                .insert(calendarId="primary", body=event_body, conferenceDataVersion=1)
                .execute()
            )
            meeting_link = response.get("hangoutLink") or "No Meeting Link"
            created_events_info.append(
                {"eventLink": response.get("htmlLink"), "meetingLink": meeting_link}
            )
        except HTTPError as e:
            print(f"HttpError when creating event: {e}")
            return False  # Skip this event and continue with the next one
        except Exception as e:
            print(f"Error creating event: {e}")

            return False  # Skip this event and continue with the next one

    message = events.get("message", "Events created successfully.")
    # Append meeting links to the message if available
    for event_info in created_events_info:
        if event_info["meetingLink"] != "No Meeting Link":
            message += f"\nMeeting Link: {event_info['meetingLink']}"

    return {"message": message, "eventsInfo": created_events_info}


def deleteGoogleCalendarEvent(accessToken: str, refreshToken: str, eventIds):
    creds = Credentials(
        token=accessToken,
        refresh_token=refreshToken,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=os.getenv("CLIENT_ID"),
        client_secret=os.getenv("CLIENT_SECRET"),
        scopes=["https://www.googleapis.com/auth/calendar"],
    )
    service = build("calendar", "v3", credentials=creds)

    success = True
    for eventId in eventIds["ids"]:
        try:
            service.events().delete(calendarId="primary", eventId=eventId).execute()
        except Exception as e:

            print(f"Error deleting event {eventId}: {e}")
            return False
    return eventIds["message"]


def editGoogleCalendarEvent(accessToken: str, refreshToken: str, jsonData, timezone):
    creds = Credentials(
        token=accessToken,
        refresh_token=refreshToken,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=os.getenv("CLIENT_ID"),
        client_secret=os.getenv("CLIENT_SECRET"),
        scopes=["https://www.googleapis.com/auth/calendar"],
    )
    service = build("calendar", "v3", credentials=creds)

    success = True
    for event in jsonData["events"]:
        # Ensure each event is a dictionary
        if not isinstance(event, dict):
            print("Each event should be a dictionary.")
            continue

        # Construct the event body
        event_body = {
            "summary": event.get("title"),
            "location": event.get("location"),
            "description": event.get("description"),
            "start": {
                "dateTime": event.get("startDate").replace("Z", ""),
                "timeZone": timezone,
            },
            "end": {
                "dateTime": event.get("endDate").replace("Z", ""),
                "timeZone": timezone,
            },
            "attendees": [
                {"email": attendee} for attendee in event.get("attendees", [])
            ],
            "reminders": {
                "useDefault": False,
                "overrides": [
                    {"method": "email", "minutes": 24 * 60},
                    {"method": "popup", "minutes": 10},
                ],
            },
        }

        if event.get("isOnlineMeeting", False):
            event_body["conferenceData"] = {
                "createRequest": {
                    "requestId": f"{int(datetime.datetime.now().timestamp())}",
                    "conferenceSolutionKey": {"type": "hangoutsMeet"},
                }
            }
        try:
            service.events().update(
                calendarId="primary", eventId=event["id"], body=event_body
            ).execute()
        except Exception as e:
            print(f"Error editing event {event['id']}: {e}")
            return False
    return jsonData["message"]


@app.route("/todaysSummary", methods=["POST"])
def todaysSummary():
    calendar_data = request.json.get("calendar")
    current_date = request.json.get("currentDate")
    userId = request.json.get("userId")

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
    response = ecApp.query(
        prompt_text,
        where={"userId": userId},
    )
    print(response)

    # Provide the response
    if response:
        return (
            jsonify({"success": True, "message": response, "response": response}),
            200,
        )
    else:
        # Provide a default message if the AI fails to generate a summary
        return jsonify({"success": True, "message": "Enjoy your free time today!"}), 200


if __name__ == "__main__":
    app.run(port=os.getenv("PORT", default=8000), host="0.0.0.0", debug=True)
