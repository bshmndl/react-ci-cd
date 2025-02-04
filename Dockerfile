# Base image
FROM node:18 AS build-stage

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the application code to the container
COPY . .

# Build the React app
RUN npm run build

# Production stage
FROM nginx:alpine AS production-stage

# Copy the build output to Nginx's html directory
COPY --from=build-stage /app/dist /usr/share/nginx/html

# Expose the port on which the app runs
EXPOSE 5137

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
