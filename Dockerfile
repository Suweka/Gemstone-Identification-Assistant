# Gemstone Identification Assistant - container for cloud hosting
# (Render, Railway, Fly.io or any Docker host).
# Uses the official SWI-Prolog image, so visitors need nothing but a browser.

FROM swipl:stable

WORKDIR /app
COPY gem_expert/ /app/

# the host sets PORT; 8080 when run locally
ENV PORT=8080
EXPOSE 8080

CMD ["swipl", "-g", "serve", "main.pl"]
