from pydantic import BaseModel, EmailStr


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str


class AdminLoginResponse(BaseModel):
    access_token: str
    token_type: str
    admin_id: int
    email: EmailStr
    full_name: str
    roles: list[str]
    permissions: list[str]


class AdminSessionRequest(BaseModel):
    """Body for the admin single-sign-on exchange endpoint.

    The user is authenticated through Bearer token (their normal user
    token). This payload is currently empty and exists so the endpoint
    keeps the same ``POST`` with JSON shape as login; we intentionally do
    not accept an email/password here.
    """

    pass