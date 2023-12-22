# Google Sheets SiS
 Streamlit In Snowflake Google Sheets Connector

 This repo contains a sample a [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit) App that uses [External Access](https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access) to ingest data from Google Sheets to a Snowflake table.
 
 Please follow the steps below to install the connnector in your Snowflake Account:

 **Step 1.** Enable the Google Sheets API by navigating to this url and clicking enable: https://console.cloud.google.com/marketplace/product/google/sheets.googleapis.com:

 **Step 2.** Create OAuth 2.0 Client ID for your GCP Project by navigating to https://console.cloud.google.com/apis/credentials:

**Step 3.** Copy and paste your OAUTH_CLIENT_ID and OAUTH_CLIENT_SECRET values into lines 56 and 57 of Google_Sheets_External_Access.sql:
![image](https://github.com/alexfrancisross/Google_Sheets_SiS/assets/11485060/7a1800e5-dcdc-4fec-9a5b-d5352d1e307c)
![image](https://github.com/alexfrancisross/Google_Sheets_SiS/assets/11485060/b8147a47-7a0c-44d7-9da0-e641ff96e223)

**Step 4.** Generate OAuth Refresh Token by navigating to this url: https://developers.google.com/oauthplayground/. Click on settings and enter your OAuth Client ID and Secret:
![image](https://github.com/alexfrancisross/Google_Sheets_SiS/assets/11485060/b471cd51-8d06-4722-bd4a-63960aee1968)

**Step 5.**  Copy and paste your Oauth refresh token into line 72 of Google_Sheets_External_Access.sql:
![image](https://github.com/alexfrancisross/Google_Sheets_SiS/assets/11485060/4768fee7-ddc3-44c6-90ca-3158442dc5a1)
![image](https://github.com/alexfrancisross/Google_Sheets_SiS/assets/11485060/e8a489a8-1f5d-4274-8cfb-a311f58746b1)

**Step 6.** Run Google_Sheets_External_Access.sql, ensuring that you upload the python libraries google.zip, gspread.zip, oauth2client.zip to the Snowflake stage @GSHEET_APP.PUBLIC.PACKAGES using the role GSHEET_ADMIN: 
![image](https://github.com/alexfrancisross/Google_Sheets_SiS/assets/11485060/68f49694-eb76-46f8-93b2-2bb2690db573)

**Step 7.** Create a new Streamlit in Snowflake app. Give it an appropriate name and select the GSHEET_WH warehouse, GSHEET_APP database, and PUBLIC schema:
![image](https://github.com/alexfrancisross/Google_Sheets_SiS/assets/11485060/2ef2c6ad-742e-40a1-a314-16da1f9133d8)

**Step 8.** Copy and paste the python code from Google_Sheets_SiS.py into your Streamlit app:
![image](https://github.com/alexfrancisross/Google_Sheets_SiS/assets/11485060/6ef193c0-c84a-4467-a18e-cec3de586d57)

Enjoy!
