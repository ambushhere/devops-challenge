FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app
COPY --chown=root:root app/app.py .

USER 10001:10001
EXPOSE 8080

# python is PID 1 and has no SIGTERM handler -> would ignore SIGTERM
STOPSIGNAL SIGINT

CMD ["python", "app.py"]