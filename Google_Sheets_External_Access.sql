/***************************************************************************************************   
Demo:         Google Sheets External Access Integration
Version:      v1.0
Script:       Google_Sheets_External_Access.sql       
Create Date:  18-12-2023
Author:       Alex Ross
****************************************************************************************************
Description: 
   Google Sheets External Access Setup for Streamlit App
****************************************************************************************************
SUMMARY OF CHANGES
Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------- ------------------------------------------------------------
18-12-2023          Alex Ross           Initial Release
***************************************************************************************************/
--1. Setup Environment
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS GSHEET_APP;
CREATE OR REPLACE DATABASE GSHEET_APP;
CREATE OR REPLACE ROLE GSHEET_ADMIN;
SET my_user_var  = CURRENT_USER();
GRANT ROLE GSHEET_ADMIN TO USER identifier($my_user_var);
CREATE OR REPLACE WAREHOUSE GSHEET_WH WITH
COMMENT = 'Warehouse for Google Sheets Streamlit App'
    WAREHOUSE_TYPE = 'standard'
    WAREHOUSE_SIZE = 'xsmall' 
    MIN_CLUSTER_COUNT = 1 
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'standard'
    AUTO_SUSPEND = 60
    AUTO_RESUME = true
    INITIALLY_SUSPENDED = true;
GRANT ALL ON DATABASE GSHEET_APP TO ROLE GSHEET_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE GSHEET_APP TO ROLE GSHEET_ADMIN; 
GRANT ALL ON ALL TABLES IN DATABASE GSHEET_APP TO ROLE GSHEET_ADMIN;
GRANT USAGE ON WAREHOUSE GSHEET_WH TO ROLE GSHEET_ADMIN;
USE ROLE GSHEET_ADMIN;
USE DATABASE GSHEET_APP;
USE SCHEMA PUBLIC;
CREATE STAGE GSHEET_APP.PUBLIC.PACKAGES;

--2. Upload Following Files To @GSHEET_APP.PUBLIC.PACKAGES STAGE: google.zip, gspread.zip, oauth2client.zip
--Go To Data->Databases->GSHEET_APP->PUBLIC->Stages->PACKAGES and clicke on +Files icon in the top right
--Check that files have been uploaded successfully
LIST @GSHEET_APP.PUBLIC.PACKAGES;
select * from information_schema.packages where language = 'python'; --and package_name='gspread';

--3. Setup Security Integration
--Enable the Google Sheets API by navigating to this url and clicking enable: https://console.cloud.google.com/marketplace/product/google/sheets.googleapis.com
--Create OAuth 2.0 Client ID for your GCP Project by navigating to https://console.cloud.google.com/apis/credentials
--Copy and paste you OAUTH_CLIENT_ID and OAUTH_CLIENT_SECRET values below
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE SECURITY INTEGRATION gsheet_oauth
  TYPE = API_AUTHENTICATION
  AUTH_TYPE = OAUTH2
  OAUTH_CLIENT_ID = '<YOUR GOOGLE OAUTH CLIENT ID>'
  OAUTH_CLIENT_SECRET = '<YOUR GOOGLE OAUTH CLIENT SECRET>'
  OAUTH_TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token'
  OAUTH_AUTHORIZATION_ENDPOINT = 'https://accounts.google.com/o/oauth2/auth'
  OAUTH_ALLOWED_SCOPES = ('https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/spreadsheets','https://www.googleapis.com/auth/drive')
  ENABLED = TRUE;
GRANT ALL ON INTEGRATION gsheet_oauth to ROLE GSHEET_ADMIN;

--4. Generate OAuth Refresh Token by navigating to this url: https://developers.google.com/oauthplayground/
--Click on settings and enter your OAuth Client ID and Secret
--Select Google Sheets APIs to be authorized
--Exchange authorization code for tokens
--Copy and paste oauth refresh token below:
CREATE OR REPLACE SECRET gsheet_oauth_token
TYPE = OAUTH2
API_AUTHENTICATION = gsheet_oauth
OAUTH_REFRESH_TOKEN ='<YOUR GOOGLE OAUTH REFRESH TOKEN>';
GRANT USAGE ON SECRET gsheet_oauth_token to role GSHEET_ADMIN;
GRANT READ ON SECRET gsheet_oauth_token to role GSHEET_ADMIN;

--5. Setup Network Rule For External Access
CREATE OR REPLACE NETWORK RULE gsheet_apis_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('sheets.googleapis.com','oauth2.googleapis.com','accounts.google.com','www.googleapis.com:443');
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION gsheet_apis_access_integration
  ALLOWED_NETWORK_RULES = (gsheet_apis_network_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (gsheet_oauth_token)
  ENABLED = true;
GRANT ALL ON INTEGRATION  gsheet_apis_access_integration TO ROLE GSHEET_ADMIN;

--6. Create SPs for reading Google Sheets data
USE ROLE GSHEET_ADMIN;
--SP to read google sheets data. Returns Snowpark DF.
CREATE OR REPLACE PROCEDURE GSHEET_APP.PUBLIC.GSHEET_READ_SP(gsheet_url STRING, worksheet_name STRING, table_name STRING, save_mode STRING, preview BOOLEAN)
RETURNS TABLE()
LANGUAGE PYTHON
RUNTIME_VERSION = 3.8
HANDLER = 'get_sheet_sp'
EXTERNAL_ACCESS_INTEGRATIONS = (gsheet_apis_access_integration)
PACKAGES = ('snowflake-snowpark-python', 'google-auth', 'google-auth-oauthlib', 'pandas', 'pyparsing')
IMPORTS = ('@PACKAGES/gspread.zip','@PACKAGES/oauth2client.zip')
SECRETS = ('cred' = gsheet_oauth_token)
AS
$$
import _snowflake
import gspread
import pandas as pd
from oauth2client.service_account import ServiceAccountCredentials
from oauth2client.client import AccessTokenCredentials

def get_sheet_sp(session, gsheet_url, worksheet_name, table_name, save_mode, preview):
  token = _snowflake.get_oauth_access_token('cred')
  credentials = AccessTokenCredentials(token, None)
  gc = gspread.authorize(credentials)
  sh = gc.open_by_url(gsheet_url)
  wks = sh.worksheet(worksheet_name)
  if preview:
    data = wks.get_values('1:10', value_render_option='UNFORMATTED_VALUE')
  else:
    data = wks.get_values(value_render_option='UNFORMATTED_VALUE')
  headers = data.pop(0)
  df = pd.DataFrame(data,columns=headers)
  sdf = session.create_dataframe(df) 
  sdf.write.mode(save_mode).save_as_table(table_name)
  return sdf
$$;

--SP to read worksheet names from google sheets document. Returns Snowpark DF.
CREATE OR REPLACE PROCEDURE GSHEET_APP.PUBLIC.GSHEET_GET_WORKSHEETS_SP(gsheet_url STRING, table_name STRING)
RETURNS TABLE()
LANGUAGE PYTHON
RUNTIME_VERSION = 3.8
HANDLER = 'get_worksheets_sp'
EXTERNAL_ACCESS_INTEGRATIONS = (gsheet_apis_access_integration)
PACKAGES = ('snowflake-snowpark-python', 'google-auth', 'google-auth-oauthlib', 'pandas', 'pyparsing')
IMPORTS = ('@PACKAGES/gspread.zip','@PACKAGES/oauth2client.zip')
SECRETS = ('cred' = gsheet_oauth_token)
AS
$$
import _snowflake
import gspread
import pandas as pd
from oauth2client.service_account import ServiceAccountCredentials
from oauth2client.client import AccessTokenCredentials

def get_worksheets_sp(session, gsheet_url, table_name):
  token = _snowflake.get_oauth_access_token('cred')
  credentials = AccessTokenCredentials(token, None)
  gc = gspread.authorize(credentials)
  sh = gc.open_by_url(gsheet_url)
  worksheet_list = sh.worksheets()
  title_lst = [k.title for k in worksheet_list]
  sdf = session.create_dataframe(title_lst,schema=["worksheet"]) 
  sdf.write.mode("overwrite").save_as_table(table_name)
  return sdf
$$;

--7. Test Harness to check if you can call SPs and read Google Sheets Successfully
CALL GSHEET_GET_WORKSHEETS_SP('<YOUR GOOGLE SHEET URL>', 'worksheets');
CALL GSHEET_READ_SP('<YOUR GOOGLE SHEET URL>', '<YOUR WORKSHEET NAME>', 'Temp', 'overwrite','False');