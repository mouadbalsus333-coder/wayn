# WAYN Backend

This backend is built with FastAPI, SQLAlchemy, Alembic, and PostgreSQL/PostGIS.

## Requirements

- Python 3.12+
- PostgreSQL
- PostGIS extension enabled

## Local Setup

1. Create a Python virtual environment:

   python -m venv .venv
   source .venv/bin/activate  # Linux / macOS
   .venv\Scripts\Activate.ps1  # Windows PowerShell

2. Install dependencies:

   pip install -r requirements.txt

3. Copy `.env.example` to `.env` and update credentials.

4. Create the database and enable PostGIS:

   CREATE DATABASE wayn_db;
   \c wayn_db;
   CREATE EXTENSION postgis;

## Run Migrations

1. Initialize Alembic (already configured):

   alembic revision --autogenerate -m "Initial migration"
   alembic upgrade head

## Run the App

Start the FastAPI app locally:

   uvicorn app.main:app --reload

## Run Tests

   pytest
