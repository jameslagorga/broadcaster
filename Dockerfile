FROM jrottenberg/ffmpeg

COPY broadcast.sh /usr/local/bin/broadcast.sh
RUN chmod +x /usr/local/bin/broadcast.sh

