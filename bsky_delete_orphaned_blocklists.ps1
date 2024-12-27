# This script needs a user did or handle
# example did:    did:plc:5iasteyttnfjalqkrflctzpy
# example handle: wkrick.bsky.social

$user = 'DID_OR_HANDLE_GOES_HERE'

# This script needs an app password to delete orphaned blocklists
# https://bsky.app/settings/app-passwords

$app_password = 'xxxx-xxxx-xxxx-xxxx'

#####################################################################
# DO NOT MODIFY ANYTHING BELOW THIS LINE
#####################################################################

$uri_base = 'https://bsky.social/xrpc'

#
# make sure user exists and look up did and handle
#
Write-Host ''
Write-Host 'Looking up user...'
$did = ''
$handle = ''
$uri_describeRepo = "$uri_base/com.atproto.repo.describeRepo?repo=$user"
try {
    $response_describeRepo = Invoke-RestMethod -Uri $uri_describeRepo
    $did = $response_describeRepo.did
    $handle = $response_describeRepo.handle
    Write-Host "did: $did"
    Write-Host "handle: $handle"
} catch {
    $message = ($_.ErrorDetails.Message | ConvertFrom-Json).message
    Write-Host "Exception when looking up user: $message"
    # we can't continue so exit early
    exit
}

# 
# create a session
#

$uri_createSession = "$uri_base/com.atproto.server.createSession"
$Headers = @{ 'Content-Type' = 'application/json' }
$Body = "{ `"identifier`": `"$did`", `"password`": `"$app_password`" }"
$result = Invoke-RestMethod -Method 'Post' -Uri $uri_createSession -Headers $Headers -Body $Body
$accessJwt = $result.accessJwt

#
# get the block lists that the user is subscribed to
#
$uri_listRecords = "$uri_base/com.atproto.repo.listRecords?repo=$did&collection=app.bsky.graph.listblock&limit=100"

$records = (Invoke-RestMethod $uri_listRecords).records
$num = $records.Length

Write-Host "$handle is subscribed to $num block lists"
Write-Host ''
Write-Host 'Testing block lists...'

#
# test each block list
#
$records | Foreach-Object {

    $subject = $_.value.subject
    $regex = '^at\:\/\/(?<repo>did\:plc\:[a-z0-9]+)\/app\.bsky\.graph\.list\/(?<rkey>[a-z0-9]+)$'
    $subject -match $regex | Out-Null
    $repo = $Matches['repo']
    $rkey = $Matches['rkey']

    $uri_getRecord = "$uri_base/com.atproto.repo.getRecord?repo=$repo&collection=app.bsky.graph.list&rkey=$rkey"
    $orphan = $false
    try {
        Invoke-RestMethod -Uri $uri_getRecord | Out-Null
    } catch {
        Write-Host '----'
        Write-Host "$subject"
        $message = ($_.ErrorDetails.Message | ConvertFrom-Json).message
        $patterns = '^Could not find repo|^Could not locate record'
        if ($message -match $patterns) {
            $orphan = $true
            Write-Host "$message"
        } else {
            Write-Host 'UNEXPECTED EXCEPTION...'
            Write-Host "$message"
        }
    }

    if (-Not $orphan) {
        return
    }

    #
    # delete orphaned blocklist
    #

    $uri = $_.uri
    $regex = '^at\:\/\/(?<repo>did\:plc\:[a-z0-9]+)\/app\.bsky\.graph\.listblock\/(?<rkey>[a-z0-9]+)$'
    $uri -match $regex | Out-Null
    $repo = $Matches['repo']
    $rkey = $Matches['rkey']

    $uri_deleteRecord = "$uri_base/com.atproto.repo.deleteRecord"
    $Headers = @{ 'Authorization' = "Bearer $accessJwt"; 'Content-Type' = 'application/json' }
    $Body = "{ `"repo`": `"$repo`", `"collection`": `"app.bsky.graph.listblock`", `"rkey`": `"$rkey`" }"
    try {
        Invoke-RestMethod -Method 'Post' -Uri $uri_deleteRecord -Headers $Headers -Body $body | Out-Null
        Write-Host "Block list deleted"
    } catch {
    }

}

Write-Host '----'
Write-Host 'Done.'
