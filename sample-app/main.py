import os
from fastapi import APIRouter, FastAPI

ROUTE_PREFIX = os.getenv("ROUTE_PREFIX", "").rstrip("/")
PR_NUMBER = os.getenv("PR_NUMBER", "local")
GIT_SHA = os.getenv("GIT_SHA", "dev")

app = FastAPI(title="Ephemeral PR Preview App")
router = APIRouter(prefix=ROUTE_PREFIX)


@router.get("/")
def root():
    return {
        "message": f"Live Preview for PR #{PR_NUMBER}!",
        "pr_number": PR_NUMBER,
        "git_sha": GIT_SHA,
        "route_prefix": ROUTE_PREFIX or "/",
    }


@router.get("/healthz")
def healthz():
    return {"status": "ok", "pr_number": PR_NUMBER}


@router.get("/version")
def version():
    return {"pr_number": PR_NUMBER, "git_sha": GIT_SHA}


app.include_router(router)
