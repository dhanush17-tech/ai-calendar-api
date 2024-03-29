# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN python -m venv /app/venv

RUN . /app/venv/bin/activate && pip install --no-cache-dir -r requirements.txt

RUN rm -rf ~/.embedchain

RUN ls

RUN export GOOGLE_APPLICATION_CREDENTIALS="cred.json"

RUN export ANTHROPIC_API_KEY="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"

# Make port 8000 available to the world outside this container

EXPOSE 8000

# Define environment variable to ensure Python output is set straight
# to the terminal without buffering it first
ENV PYTHONUNBUFFERED 1

# Run main.py when the container launches
CMD ["/app/venv/bin/python", "main.py"]
