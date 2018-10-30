# Embedded signing ceremony
#
# Check that we're in a bash shell
if [[ $SHELL != *"bash"* ]]; then
  echo "PROBLEM: Run these scripts from within the bash shell."
fi

# Settings
# Fill in these constants
#
# Obtain an OAuth access token from https://developers.hqtest.tst/oauth-token-generator
accessToken='{ACCESS_TOKEN}'
# Obtain your accountId from demo.docusign.com -- the account id is shown in the drop down on the
# upper right corner of the screen by your picture or the default picture. 
accountId='{ACCOUNT_ID}'
# Recipient Information:
signerName='{USER_FULLNAME}'
signerEmail='{USER_EMAIL}'
# The document you wish to send. Path is relative to the root directory of this repo.
fileNamePath='../demo_documents/World_Wide_Corp_lorem.pdf'

clientUserId='123'  # Used to indicate that the signer will use an embedded
                    # Signing Ceremony. Represents the signer's userId within
                    # your application.
authenticationMethod='None'  # How is this application authenticating
                             # the signer? See the `authenticationMethod' definition
                             # https://developers.docusign.com/esign-rest-api/reference/Envelopes/EnvelopeViews/createRecipient
# The API base_path
basePath='https://demo.docusign.net/restapi'

#
# Step 1. Create the envelope.
#         One signHere tab is added.
#         The signer recipient includes a clientUserId setting

# temp files:
request_data=$(mktemp /tmp/request-eg-001.XXXXXX)
response=$(mktemp /tmp/response-eg-001.XXXXXX)
doc1_base64=$(mktemp /tmp/eg-001-doc1.XXXXXX)

echo ""
echo "Sending the envelope request to DocuSign..."

# Fetch doc and encode
cat $fileNamePath | base64 > $doc1_base64
# Concatenate the different parts of the request
printf \
'{
    "emailSubject": "Please sign this document",
    "documents": [
        {
            "documentBase64": "' > $request_data
cat $doc1_base64 >> $request_data
printf \
'",
            "name": "Lorem Ipsum",
            "fileExtension": "pdf",
            "documentId": "1"
        }
    ],
    "recipients": {
        "signers": [
            {
                "email": "${signer_name}",
                "name": "${signer_email}",
                "recipientId": "1",
                "routingOrder": "1",
                "clientUserId": "${clientUserId}",
                "tabs": {
                    "signHereTabs": [
                        {
                            "documentId": "1", "pageNumber': "1",
                            "recipientId": "1", "tabLabel": 'SignHereTab',
                            "xPosition": "195", "yPosition": "147"
                        }
                    ]
                }
            }
        ]
    },
    "status": "sent"
}' >> $request_data

curl --header "Authorization: Bearer ${accessToken}" \
     --header "Content-Type: application/json" \
     --data-binary @${request_data} \
     --request POST ${basePath}/v2/accounts/${accountId}/envelopes \
     --output ${response}

echo ""
echo "Response:"
cat $response
echo ""

# pull out the envelopeId
ENVELOPE_ID=`cat $response | grep envelopeId | sed 's/.*\"envelopeId\": \"//' | sed 's/\",//' | tr -d '\r'`
echo "EnvelopeId: ${ENVELOPE_ID}"

# Step 2. Create a recipient view (a signing ceremony view)
#         that the signer will directly open in their browser to sign.
#
# The returnUrl is normally your own web app. DocuSign will redirect
# the signer to returnUrl when the signing ceremony completes.
# For this example, we'll use http://httpbin.org/get to show the 
# query parameters passed back from DocuSign

echo ""
echo "Requesting the url for the signing ceremony..."
curl --header "Authorization: Bearer {ACCESS_TOKEN}" \
     --header "Content-Type: application/json" \
     --data-binary '
{
    "returnUrl": "http://httpbin.org/get",
    "authenticationMethod": "${authenticationMethod}",
    "email": "${signerEmail}",
    "userName": "${signerName}",
    "clientUserId": 1000,
}' \
     --request POST ${basePath}/v2/accounts/${accountId}/envelopes/${ENVELOPE_ID}/views/recipient \
     --output ${response}

echo ""
echo "Response:"
cat $response
echo ""

SIGNING_CEREMONY_URL=`cat $response | grep url | sed 's/.*\"url\": \"//' | sed 's/\"//' | tr -d '\r'`
echo ""
echo "Attempting to automatically open your browser to the signing ceremony url..."
if which open > /dev/null 2>/dev/null
then
  open "$SIGNING_CEREMONY_URL"
elif which start > /dev/null
then
  start "$SIGNING_CEREMONY_URL"
fi

# cleanup
rm "$request_data"
rm "$response"
rm "$doc1_base64"

echo ""
echo ""
echo "Done."
echo ""


