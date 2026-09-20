FROM python:3.14-slim

RUN apt-get update && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:0.12.17 /uv /uvx /bin/

WORKDIR /app

ENV PATH="/app/.venv/bin:$PATH"

COPY pyproject.toml uv.lock ./

RUN --mount=type=secret,id=gh_token \
    git config --global url."https://x-access-token:$(cat /run/secrets/gh_token)@github.com/".insteadOf "https://github.com/" \
 && uv sync --frozen --no-dev --no-install-project \
 && git config --global --unset-all url."https://x-access-token:$(cat /run/secrets/gh_token)@github.com/".insteadOf

COPY src ./src

RUN uv sync --locked

EXPOSE 8000

CMD ["python", "-m", "testapp"]

