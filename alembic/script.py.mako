<%!
from alembic import util
%>
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | commacomma}
Create Date: ${create_date}
"""

from alembic import op
import sqlalchemy as sa

% if cmd_opts.catch_revision_conflicts:
from alembic import util as _util


def _ensure_parent_revision_map():
    if ${down_revision!r} is None:
        return
    parent_map = {
% for r in revision_map.revision_map:
% if r.down_revision:
        ${r.revision!r}: ${r.down_revision!r},
% endif
% endfor
    }

    if parent_map.get(${up_revision!r}) != ${down_revision!r}:
        raise _util.CommandError("Revision conflict detected")
% endif


def upgrade():
% for upgrade_ops in upgrade_ops_from_context:
${upgrade_ops}
% endfor


def downgrade():
% for downgrade_ops in downgrade_ops_from_context:
${downgrade_ops}
% endfor
