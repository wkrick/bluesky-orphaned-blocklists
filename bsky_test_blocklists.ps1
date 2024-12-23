# This script needs a user did or handle
# example did:    did:plc:5iasteyttnfjalqkrflctzpy
# example handle: wkrick.bsky.social

$user = 'DID_OR_HANDLE_GOES_HERE'

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
    try {
        Invoke-RestMethod -Uri $uri_getRecord | Out-Null
    } catch {
        Write-Host '----'
        Write-Host "$subject"
        $message = ($_.ErrorDetails.Message | ConvertFrom-Json).message
        Write-Host "$message"
    }
}

Write-Host '----'
Write-Host 'Done.'
