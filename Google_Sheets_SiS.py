# Import python packages
import streamlit as st
import random
from snowflake.snowpark.context import get_active_session

if "gsheet_url" not in st.session_state:
  st.session_state.gsheet_url = ''

def validated_target() -> bool:
    if not st.session_state.get("table_name"):
        main_container.error("A target table name needs to be provided.")
        return False
    return True

def validate_source() -> bool:
    if not st.session_state.get("gsheet_url"): 
        main_container.error("A Google Sheets URL needs to be provided'")
        return False
    return True

def upload(
) -> None:
    if validated_target() and validate_source():
        with main_container:
            with st.spinner(text="Upload in progress."):
                try:
                    # Write the connection object to Snowflake
                    rows = upload_gsheet(
                        st.session_state.table_name,
                        st.session_state.save_mode,
                        st.session_state.gsheet_url
                    )
                    st.success(str(rows) + " rows inserted to table " + st.session_state.table_name )
                # Catch any errors that occur and display it on the UI
                except Exception as ex:
                    st.error(ex)

def preview(
) -> None:
    if validate_source():
        with main_container:
            with st.spinner(text="Preview in progress."):
                try:
                    # preview gsheet
                    preview_gsheet(
                        st.session_state.gsheet_url
                    )
                # Catch any errors that occur and display it on the UI
                except Exception as ex:
                    st.error(ex)

def preview_gsheet( gsheet_url
) -> None:
    #st.write("Reading Google Sheet...")
    session = get_active_session()
    wsheet_name = worksheet
    table_name = 'TEMP_'+ str(random.getrandbits(128))
    preview = True
    save_mode = 'overwrite'
    
    df = session.call("gsheet_read_sp",gsheet_url, wsheet_name, table_name, save_mode, preview)
    df.collect()    
    
    t_show = session.table(table_name)
    st.dataframe(t_show)
    t_show.drop_table()

def upload_gsheet( table_name, save_mode, gsheet_url
) -> None:
    #st.write("Loading data into table " + table_name + "...")
    session = get_active_session()
    wsheet_name = worksheet
    preview = False
    #table_name = table_name

    df = session.call("gsheet_read_sp",gsheet_url, wsheet_name, table_name,save_mode, preview)
    #df.collect()
    return df.count()

@st.cache_data(ttl=3600)
def update_wsheet_name(gsheet_url
) -> None:
    session = get_active_session()
    if gsheet_url !='':
        try:
            table_name = 'worksheets'
            df = session.call("GSHEET_APP.PUBLIC.GSHEET_GET_WORKSHEETS_SP",gsheet_url,table_name)
            df.collect() 
            
            t = session.table(table_name)
            st.session_state.wsheet_names=t
           
        # Catch any errors that occur and display it on the UI
        except Exception as ex:
            st.error('Error Getting Worksheet Names. Please ensure you enetered a valid Google Sheet URL and have shared with your service account')
            st.error(ex)
    else: 
        st.session_state.wsheet_names = ['Please Enter A Valid Google Sheet URL!']

# Set header 
col1, mid, col2 = st.columns([1,1,20])
with col1:
    st.image('https://www.gstatic.com/images/branding/product/2x/sheets_2020q4_48dp.png', width=60)
with col2:
    st.header('Google Sheets Data Loader')


st.info(''' 
- Worksheet must contain column headers in first row
- New tables are written to GSHEET_APP.PUBLIC schema by default
- Ensure you have shared your Google Sheet with your Google Service Account''', icon="ℹ️")

# Container to keep all objects together and in the correct order
main_container = st.container()

# Define the main input widgets
main_container.text_input(
    key="table_name", 
    label="Target Snowflake Table Name", 
    placeholder="MY_SNOWFLAKE_TABLE", 
    #value="GSHEET_TABLE"
)

url = "https://docs.snowflake.com/en/developer-guide/snowpark/reference/python/latest/api/snowflake.snowpark.DataFrameWriter.mode#snowflake.snowpark.DataFrameWriter.mode"
main_container.radio(
    key="save_mode",
    label="Save Mode (see Snowflake [docs](https://docs.snowflake.com/en/developer-guide/snowpark/reference/python/latest/api/snowflake.snowpark.DataFrameWriter.mode#snowflake.snowpark.DataFrameWriter.mode))",
    horizontal=True,
    index=0,
    options=["overwrite","append","errorifexists","ignore"],
).lower()

# Build Google Sheet specific widgets
main_container.text_input(
    key="gsheet_url",
    label="Google Sheet URL",
    placeholder="https://docs.google.com/spreadsheets/...",
    on_change=update_wsheet_name(st.session_state.gsheet_url)
)

# Build Google Sheet specific widgets
worksheet = main_container.selectbox(
    key="wsheet_name",
    label="Worksheet Name",
    options=st.session_state.wsheet_names
)

# Create columns to align buttons
col_left, col_right = main_container.columns([1, 4])

# Add buttons to perform actions
col_left.button(
    "Start Import",
    on_click=upload,
    type="primary",
)
col_right.button(
    "Preview Data",
    on_click=preview,
)
