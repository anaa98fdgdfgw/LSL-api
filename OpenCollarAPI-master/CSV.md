# OpenCollarAPI CSV Format #

Standards for the text/CSV responses to OpenCollarAPI requests. 


The OpenCollarAPI specifies that some response data is of the type "text/CSV". 
While this format is a recognized MIME type, it is still somewhat unclear. 
This document specifies the information and file format associated with these
responses. 

There are three aspects of the CSV specification:     

	+ File Specs
	+ Content
	+ Dialect
	
## File Specs ## 
The specifications of the file including name and text encoding. The OpenCollarAPI 

	+ Filename: specified in response Header "filename". This is documented in the OpenAPI specification
	+ Text Encoding: UTF-8

## Content ##
The content of the CSV is the name of the fields and the data in each field. 
Each response that generates a CSV has a corresponding JSON response. The CSV content
must be the same as the JSON content. This means that the header names are the JSON fields, 
and the field data are the corresponding JSON values. There are numerous open tools available 
for developers to automatically convert between JSON and CSV. 

## Dialect ##
The dialect of the CSV is the information regarding how fields and lines are delimitted. 
This is described using the [CSV Dialect](https://frictionlessdata.io/specs/csv-dialect/) 
format. The CSV Dialect format uses a JSON object to describe the delimitters, line endings, 
etc. This JSON object is included with the project as csvFormat.json

## Additional Note ##
A valid CSV has AT MOST 1 line of header fields. There can be no lines that are not headers or data.
Vendors must adhere to this. No CSV interpreter accepts multiple header lines or non-data lines.
DO NOT INCLUDE ANY MORE THAN ONE HEADER LINE. 
