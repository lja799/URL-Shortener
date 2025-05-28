import os
import uuid
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from azure.cosmos import CosmosClient, exceptions

app = FastAPI()

# Allow requests from the frontend
origins = [
    "https://url-shortener.lemonsmoke-f7613deb.australiaeast.azurecontainerapps.io",  # Replace with your frontend app URL
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Environment variables (set in Azure Container App)
COSMOS_URI = os.getenv("COSMOS_URI")
COSMOS_KEY = os.getenv("COSMOS_KEY")
COSMOS_DB = os.getenv("COSMOS_DB", "urlshortenerdb")
COSMOS_CONTAINER = os.getenv("COSMOS_CONTAINER", "urls")

# Connect to Cosmos DB
client = CosmosClient(COSMOS_URI, credential=COSMOS_KEY)
db = client.get_database_client(COSMOS_DB)
container = db.get_container_client(COSMOS_CONTAINER)

# Request model
class URLItem(BaseModel):
    url: str

# POST /shorten
@app.post("/shorten")
def shorten_url(item: URLItem):
    short_id = str(uuid.uuid4())[:8]
    container.upsert_item({
        "id": short_id,
        "url": item.url
    })
    return { "short_id": short_id }

# GET /{short_id}
@app.get("/{short_id}")
def resolve_url(short_id: str):
    try:
        item = container.read_item(item=short_id, partition_key=short_id)
        return RedirectResponse(url=item["url"])
    except exceptions.CosmosResourceNotFoundError:
        raise HTTPException(status_code=404, detail="URL not found")
