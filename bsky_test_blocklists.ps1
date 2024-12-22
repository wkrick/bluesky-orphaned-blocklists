$user = 'HANDLE_OR_DID_GOES_HERE'

# example handle: wkrick.bsky.social
# example did:    did:plc:5iasteyttnfjalqkrflctzpy

$uri_base = 'https://bsky.social/xrpc'

$handle = ''
$did = ''
$uri_describeRepo = "$uri_base/com.atproto.repo.describeRepo?repo=$user"
try {
    $response_describeRepo = Invoke-RestMethod -Uri $uri_describeRepo
    $handle = $response_describeRepo.handle
    $did = $response_describeRepo.did
    Write-Host 'User exists'
    Write-Host "did: $did"
    Write-Host "handle: $handle"
} catch {
    $message = ($_.ErrorDetails.Message | ConvertFrom-Json).message
    Write-Host "Exception when looking up user: $message"
    exit
}

$uri_listRecords = "$uri_base/com.atproto.repo.listRecords?repo=$did&collection=app.bsky.graph.listblock"

$records = (Invoke-RestMethod $uri_listRecords).records
$num = $records.Length

Write-Host "$handle is subscribed to $num block lists"
Write-Host 'Testing...'

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
        Write-Host "Exception when testing list: $subject"
        $message = ($_.ErrorDetails.Message | ConvertFrom-Json).message
        Write-Host "Error message: $message"
    }
}
