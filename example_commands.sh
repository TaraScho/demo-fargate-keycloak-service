export KEYCLOAK_ADMIN_USER=admin
export KEYCLOAK_ADMIN_PASSWORD="admin"
export KEYCLOAK_DNS_NAME=keycloak-alb-1638832286.us-east-1.elb.amazonaws.com
export KEYCLOAK_USER_PASSWORD="FakePassword123!"
export DEFAULT_REALM_NAME=master
export DEMO_APP_REALM_NAME=coolCourseswithLogging

#get token
KEYCLOAK_ADMIN_TOKEN=$(curl -X POST "http://$KEYCLOAK_DNS_NAME/realms/$DEFAULT_REALM_NAME/protocol/openid-connect/token" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "username=$KEYCLOAK_ADMIN_USER" \
-d "password=$KEYCLOAK_ADMIN_PASSWORD" \
-d 'grant_type=password' \
-d 'client_id=admin-cli' | jq -r '.access_token')

#create new realm with event logging enabled
curl -X POST "http://$KEYCLOAK_DNS_NAME/admin/realms" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEYCLOAK_ADMIN_TOKEN" \
  -d "{
        \"realm\": \"$DEMO_APP_REALM_NAME\",
        \"enabled\": true,
        \"displayName\": \"Cool Courses\",
        \"attributes\": {},
        \"bruteForceProtected\": false,
        \"defaultRoles\": [\"offline_access\", \"uma_authorization\"],
        \"requiredCredentials\": [\"password\"],
        \"registrationAllowed\": true
      }"


              \"eventsEnabled\": true,
        \"adminEventsEnabled\": true,
        \"adminEventsDetailsEnabled\": true,
        \"eventListeners\": [\"jboss-logging\"],

#create new user with email verified
curl -X POST "http://$KEYCLOAK_DNS_NAME/admin/realms/$DEMO_APP_REALM_NAME/users" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $KEYCLOAK_ADMIN_TOKEN" \
-d "{
      \"username\": \"newuser5\",
      \"enabled\": true,
      \"email\": \"newuser5@example.com\",
      \"firstName\": \"New\",
      \"lastName\": \"User\",
      \"emailVerified\": true,
      \"credentials\": [
        {
          \"type\": \"password\",
          \"value\": \"$KEYCLOAK_USER_PASSWORD\",
          \"temporary\": false
        }
      ],
      \"attributes\": {
        \"custom_attribute\": \"custom_value\"
      }
    }"

#create public web client for web app
curl -X POST "http://$KEYCLOAK_DNS_NAME/admin/realms/$DEMO_APP_REALM_NAME/clients" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $KEYCLOAK_ADMIN_TOKEN" \
-d '{
  "clientId": "cool-courses-web-app",
  "name": "Cool Courses Public Client",
  "description": "Client for cool courses web app",
  "enabled": true,
  "publicClient": true,
  "redirectUris": [
    "http://localhost:8080/*"
  ],
  "webOrigins": [ "*" ],
  "protocol": "openid-connect",
  "attributes": {
    "saml.assertion.signature": "false",
    "saml.force.post.binding": "false",
    "saml.multivalued.roles": "false",
    "saml.encrypt": "false",
    "saml.server.signature": "false",
    "saml.server.signature.keyinfo.ext": "false",
    "exclude.session.state.from.auth.response": "false",
    "saml_force_name_id_format": "false",
    "saml.client.signature": "false",
    "tls.client.certificate.bound.access.tokens": "false",
    "saml.authnstatement": "false",
    "display.on.consent.screen": "false",
    "saml.onetimeuse.condition": "false"
  },
  "authenticationFlowBindingOverrides": {},
  "fullScopeAllowed": true,
  "nodeReRegistrationTimeout": -1,
  "protocolMappers": [
    {
      "name": "email",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "email",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "email",
        "jsonType.label": "String"
      }
    }
  ],
  "defaultClientScopes": ["web-origins", "role_list", "profile", "email"],
  "optionalClientScopes": ["offline_access", "address", "phone", "microprofile-jwt"]
}'

#get client id for web app client
CLIENT_UUID=$(curl -X GET "http://$KEYCLOAK_DNS_NAME/admin/realms/$DEMO_APP_REALM_NAME/clients?clientId=cool-courses-web-app" \
-H "Authorization: Bearer $KEYCLOAK_ADMIN_TOKEN" \
-H "Content-Type: application/json" | jq -r '.[0].id')