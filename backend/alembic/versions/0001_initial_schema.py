from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects import postgresql

revision = '0001_initial_schema'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'categories',
        sa.Column('id', postgresql.UUID(as_uuid=False), primary_key=True, nullable=False),
        sa.Column('name_ar', sa.String(length=255), nullable=False),
        sa.Column('name_en', sa.String(length=255), nullable=True),
        sa.Column('icon', sa.String(length=255), nullable=True),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    )

    op.create_table(
        'places',
        sa.Column('id', postgresql.UUID(as_uuid=False), primary_key=True, nullable=False),
        sa.Column('category_id', postgresql.UUID(as_uuid=False), sa.ForeignKey('categories.id', ondelete='SET NULL'), nullable=True),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('city', sa.String(length=255), nullable=False),
        sa.Column('category', sa.String(length=255), nullable=False),
        sa.Column('image_url', sa.String(length=1024), nullable=False),
        sa.Column('rating', sa.Float(), nullable=False, server_default='0'),
        sa.Column('is_open', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('address', sa.String(length=1024), nullable=True),
        sa.Column('phone', sa.String(length=64), nullable=True),
        sa.Column('website', sa.String(length=1024), nullable=True),
        sa.Column('latitude', sa.Float(), nullable=True),
        sa.Column('longitude', sa.Float(), nullable=True),
        sa.Column('location', Geography(geometry_type='POINT', srid=4326), nullable=True),
        sa.Column('images', sa.JSON(), nullable=False, server_default='[]'),
        sa.Column('services', sa.JSON(), nullable=False, server_default='[]'),
        sa.Column('opening_time', sa.String(length=16), nullable=True),
        sa.Column('closing_time', sa.String(length=16), nullable=True),
        sa.Column('reviews_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('visits_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    )

    op.create_index('ix_places_category_id', 'places', ['category_id'])
    op.create_index('ix_places_location', 'places', ['location'], postgresql_using='gist')


def downgrade() -> None:
    op.drop_index('ix_places_location', table_name='places')
    op.drop_index('ix_places_category_id', table_name='places')
    op.drop_table('places')
    op.drop_table('categories')
