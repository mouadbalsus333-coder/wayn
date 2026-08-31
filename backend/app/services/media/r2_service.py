from __future__ import annotations

from typing import BinaryIO

import boto3
from botocore.client import BaseClient

from app.core.config import settings


class R2Service:
    def __init__(self) -> None:
        self.client: BaseClient = boto3.client(
            "s3",
            endpoint_url=settings.r2_endpoint_url,
            aws_access_key_id=settings.r2_access_key_id,
            aws_secret_access_key=settings.r2_secret_access_key,
            region_name=settings.r2_region,
        )

        self.bucket_name = settings.r2_bucket_name

    def upload_file(
        self,
        file_object: BinaryIO,
        object_key: str,
        content_type: str,
    ) -> None:
        self.client.upload_fileobj(
            file_object,
            self.bucket_name,
            object_key,
            ExtraArgs={
                "ContentType": content_type,
            },
        )

    def get_file(
        self,
        object_key: str,
    ) -> tuple[bytes, str]:
        response = self.client.get_object(
            Bucket=self.bucket_name,
            Key=object_key,
        )

        content_type = response.get(
            "ContentType",
            "image/webp",
        )

        file_bytes = response["Body"].read()

        return file_bytes, content_type

    def delete_file(
        self,
        object_key: str,
    ) -> None:
        self.client.delete_object(
            Bucket=self.bucket_name,
            Key=object_key,
        )


r2_service = R2Service()