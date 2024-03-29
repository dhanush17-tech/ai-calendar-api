import datetime
import json
import os
import re
import time
import anthropic
from flask import Flask, request, jsonify
from httpx import HTTPError, Timeout
import requests
from tool_use_package.tool_user import ToolUser
from google.oauth2 import service_account


# from embedchain import App
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
import datetime
from dotenv import load_dotenv
import httpx
from openai import OpenAI
from embedchain import App as embedchainApp

import vertexai
from vertexai.preview.generative_models import GenerativeModel
import vertexai.preview.generative_models as generative_models
import google.generativeai as genai

app = Flask(__name__)
os.environ["GOOGLE_API_KEY"] = os.environ.get("GOOGLE_API_KEY")
os.environ["OPENAI_API_KEY"] = "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"
client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))
# client = anthropic.Anthropic(
#     # defaults to os.environ.get("ANTHROPIC_API_KEY")
#     api_key=os.environ.get("ANTHROPIC_API_KEY"),
# )
genai.configure(api_key=os.environ.get("GOOGLE_API_KEY"))
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
    isTestUser = request.json.get("isTestUser")

    print(refreshToken)
    print(accessToken)
    print("Thsi is test" + str(isTestUser))

    if isTestUser:
        events = [
            {
                "title": "Test Event",
                "description": "This is a test event",
                "location": "Test Location",
                "startDate": "2022-05-05T12:00:00Z",
                "endDate": "2022-05-05T14:00:00Z",
                "timeZone": "UTC",
                "meetingLink": "https://meet.google.com/abc-def-ghi",
                "attendees": ["test@gmail.com"],
                "id": "testId",
                "isCompleted": True,
            }
        ]
        return jsonify({"success": True, "events": events}), 200

    try:
        events = listGoogleCalendarEvents(accessToken, refreshToken)

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
    isTestUser = request.json.get("isTestUser")

    current_date = request.json.get("currentDate")
    print(events)
    print(prompt)
    print(context)
    print(current_date)

    config = {"max_output_tokens": 2048, "temperature": 0.9, "top_p": 1}
    # model = GenerativeModel("gemini-1.0-pro-001")

    chat_prompt = genai.GenerativeModel("gemini-1.0-pro-001").start_chat()
    output = (
        chat_prompt.send_message(
            f"""
    #                         Respond with a JSON structure tailored to user requests. Include "EDIT", "DELETE", "ADD" actions with the necessary fields in the specified order. Utilize "MORE" to request missing details. The "GENERAL" action should be used for broader inquiries or summaries related to the user's calendar, including a comprehensive summary of the day's schedule when asked. Summaries should be detailed within the 'message' itself, without an 'events' field for "GENERAL" actions. Structure responses in clear JSON, using human-readable date formats in messages.
    # Reminders SHOULD also be considered as Events
    # 1. Editing Events ("EDIT"):
    # {{
    #   "message": "Here are the updates to your events...",
    #   "events": [
    #     {{
    #       "startDate": "Start time of the event in ISO8601 format. MANDATORY.",
    #       "endDate": "End time of the event in ISO8601 format. MANDATORY",
    #       "title": "Event title.",
    #       "description": "Event details (optional).",
    #       "isOnlineMeeting": "true/false",
    #       "attendees": ["List of event participants (optional)."],
    #       "location": "Event location (optional).",
    #       "id": "Event ID."
    #     }}
    #   ],
    #   "action": "EDIT"
    # }}
    # 2. Deleting Events ("DELETE"):
    # {{
    #   "message": "The following events have been removed from your calendar...",
    #   "ids": ["IDs of the events to be deleted."],
    #   "action": "DELETE"
    # }}
    # 3. Adding Events ("ADD"):
    # {{
    #   "message": "New events have been added to your calendar...",
    #   "events": [
    #     {{
    #       "startDate": "Event start time in ISO8601 format.",
    #       "endDate": "Event end time in ISO8601 format.",
    #       "title": "Event title.",
    #       "description": "Event details (optional).",
    #       "isOnlineMeeting": "true/false",
    #       "attendees": ["Event participants (optional)."],
    #       "location": "Event location (optional)."
    #     }}
    #   ],
    #   "action": "ADD"
    # }}
    # 4. General Chat ("GENERAL"):
    # For general inquiries or summaries related to the user's calendar:
    # - If asked about the day: The 'message' should contain a comprehensive summary of all scheduled activities for the current date, including brief descriptions, start and end times, and meeting links if applicable, all in a conversational and human-like manner.
    # - For other general calendar-related inquiries: The 'message' should address the query directly, providing relevant information or guidance.
    # {{
    #   "message": Reply to the user's request in a very chill human like way,
    #   "action": "GENERAL"
    # }}
    # 5. Further Enquiries ("MORE"):
    # {{
    #   "message": "Could you provide more details on...",
    #   "action": "MORE"
    # }}
    # 'message' SHOULD be a MARKDOWN TEXT
    # - Context for our chat:
    # {context}
    # - Today's date is:
    # {current_date}
    # - The calendar events:
    # {events}
    # - Your request:
    # {prompt}""",
            generation_config=config,
        )
        .text.replace("`", "")
        .replace("json", "")
    )

    print(output)
    jsonData = json.loads(output, strict=False)

    # return jsonify({"success": True, "message":jsonData["message"], "response": jsonData["message"]}), 200

    if jsonData["action"] == "GENERAL":
        print("General chat")
        return jsonify(
            {
                "success": True,
                "message": jsonData["message"],
                "response": jsonData["message"],
                "action": jsonData["action"],
            }
        )
    if isTestUser:
        return jsonify(
            {
                "success": True,
                "message": "Please signin with your google account to make changes to your calendar",
                "response": "Please signin with your google account to make changes to your calendar",
                "action": jsonData["action"],
            }
        )
    else:
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

            if jsonData["action"] == "DELETE":
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
    creds = service_account.Credentials.from_service_account_file(
        "./cred.json",
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
    creds = service_account.Credentials.from_service_account_file(
        "./cred.json",
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
    creds = service_account.Credentials.from_service_account_file(
        "./cred.json",
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
    accessToken = request.json.get("accessToken")
    refreshToken = request.json.get("refreshToken")
    currentSummary = request.json.get("currentSummary")
    # Format the calendar data as a JSON string if it's not already a string
    # Construct the prompt to analyze the calendar and summarize today's events

    print(
        "Thsi is"
        + str(
            currentSummary != ""
            and calendar_data == listGoogleCalendarEvents(accessToken, refreshToken)
        )
    )
    if currentSummary != "" and calendar_data == listGoogleCalendarEvents(
        accessToken, refreshToken
    ):
        return (
            jsonify(
                {"success": True, "message": currentSummary, "response": currentSummary}
            ),
            200,
        )

    prompt_text = (
        f"Analyze the provided calendar data:{calendar_data}"
        f"summarize the events for the current date ({current_date}). "
        f"Give me the summary of the events for the {current_date}"
        "The summary should be friendly, casual"
        "Give them a heads up"
        "If there is a meeting, provide the meeting link"
        "Make it short and concise as possible. "
        "'should ONLY be a MARKDOWN TEXT"
        f"If no events are scheudled for {current_date}, then tell them to enjoy their free time today!"
    )

    response = client.chat.completions.create(
        model="gpt-3.5-turbo",
        max_tokens=1000,
        temperature=0,
        messages=[
            {"role": "user", "content": [{"type": "text", "text": prompt_text}]},
            {
                "role": "assistant",
                "content": [{"type": "text", "text": "{"}],
            },
        ],
    )

    response = response.choices[0].message.content
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
