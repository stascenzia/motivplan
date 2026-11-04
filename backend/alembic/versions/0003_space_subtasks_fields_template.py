"""capture space, subtasks, template fields and section template (ADR-016)

Revision ID: 0003
Revises: 0002
Create Date: 2026-11-04 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0003'
down_revision: Union[str, Sequence[str], None] = '0002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    with op.batch_alter_table('sections', schema=None) as batch_op:
        batch_op.add_column(sa.Column('template', sa.String(length=16), nullable=True))

    with op.batch_alter_table('tasks', schema=None) as batch_op:
        batch_op.add_column(sa.Column('space', sa.String(length=16), nullable=True))
        batch_op.add_column(sa.Column('subtasks', sa.Text(), nullable=True))
        batch_op.add_column(sa.Column('fields', sa.Text(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table('tasks', schema=None) as batch_op:
        batch_op.drop_column('fields')
        batch_op.drop_column('subtasks')
        batch_op.drop_column('space')

    with op.batch_alter_table('sections', schema=None) as batch_op:
        batch_op.drop_column('template')
