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