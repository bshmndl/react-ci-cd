FROM node:20-alpine

WORKDIR /app

COPY package*.json .

RUN npm install

COPY . .
#exposing the app on port 80  
EXPOSE 80

CMD [ "npm","run","dev" ]