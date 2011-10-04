//
//  UAGithubEngine.m
//  UAGithubEngine
//
//  Created by Owain Hunt on 02/04/2010.
//  Copyright 2010 Owain R Hunt. All rights reserved.
//

#import "UAGithubEngine.h"
#import "UAReachability.h"

#import "UAGithubSimpleJSONParser.h"
#import "UAGithubUsersJSONParser.h"
#import "UAGithubRepositoriesJSONParser.h"
#import "UAGithubMilestonesJSONParser.h"
#import "UAGithubCommitsJSONParser.h"
#import "UAGithubIssuesJSONParser.h"
#import "UAGithubIssueCommentsJSONParser.h"

#import "UAGithubEngineRequestTypes.h"
#import "UAGithubURLConnection.h"

#import "NSString+UAGithubEngineUtilities.h"
#import "NSData+Base64.h"

#define API_PROTOCOL @"https://"
#define API_DOMAIN @"github.com/api"
#define API_VERSION @"v2"
#define API_FORMAT @"json"


@interface UAGithubEngine (Private)

- (NSString *)sendRequest:(NSString *)path requestType:(UAGithubRequestType)requestType responseType:(UAGithubResponseType)responseType;
- (NSString *)sendRequest:(NSString *)path requestType:(UAGithubRequestType)requestType responseType:(UAGithubResponseType)responseType withParameters:(id)params;
- (BOOL)isValidSelectorForDelegate:(SEL)selector;

@end


@implementation UAGithubEngine

@synthesize delegate, username, password, connections, reachability, isReachable;


#pragma mark Initializer

- (id)initWithUsername:(NSString *)aUsername password:(NSString *)aPassword delegate:(id)theDelegate withReachability:(BOOL)withReach
{
	if ((self = [super init])) 
	{
		username = [aUsername retain];
		password = [aPassword retain];
		delegate = theDelegate;
		connections = [[NSMutableDictionary alloc] initWithCapacity:0];
		if (withReach)
		{
			reachability = [[UAReachability alloc] init];
		}
	}
	
	
	return self;
		
}


- (void)dealloc
{
	[username release];
	[password release];
	[connections release];
	[reachability release];
	delegate = nil;
	
	[super dealloc];
	
}


- (UAReachability *)reachability
{
	if (!reachability)
	{
		reachability = [[UAReachability alloc] init];
	}
	
	return reachability;
}


#pragma mark Delegate Check

- (BOOL)isValidSelectorForDelegate:(SEL)selector
{
	return ((delegate != nil) && [delegate respondsToSelector:selector]);
}


#pragma mark -
#pragma mark Reachability Check

- (BOOL)isReachable
{
	return [self.reachability currentReachabilityStatus];
}	


#pragma mark Request Management

- (NSString *)sendRequest:(NSString *)path requestType:(UAGithubRequestType)requestType responseType:(UAGithubResponseType)responseType withParameters:(id)params
{
    
    NSMutableString *urlString;
    
    switch (requestType) 
    {
        // V2 requests
        case 0:

            urlString = [NSMutableString stringWithFormat:@"%@%@/%@/%@/%@", API_PROTOCOL, API_DOMAIN, API_VERSION, API_FORMAT, path];

            break;
        
        // V3 Requests
        default:
            urlString = [NSMutableString stringWithFormat:@"%@api.github.com/%@", API_PROTOCOL, path];
            break;
    }
    
    NSData *jsonData = nil;
    NSError *error = nil;
    
    if ([params count] > 0)
    {
        jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
    }

    NSMutableString *querystring = nil;

    if (!jsonData && [params count] > 0) 
	{
        // API v3 means we're passing more parameters in the querystring than previously.
        // Is the querystring already present (ie a question mark is present in the path)? Create it if not.        
        if ([path rangeOfString:@"?"].location == NSNotFound)
        {
            querystring = [NSMutableString stringWithString:@"?"];
        }
        
		for (NSString *key in [params allKeys]) 
		{
			[querystring appendFormat:@"%@%@=%@", [querystring length] <= 1 ? @"" : @"&", key, [[params valueForKey:key] encodedString]];
		}
	}

    if ([querystring length] > 0)
	{
		[urlString appendString:querystring];
	}

	NSURL *theURL = [NSURL URLWithString:urlString];
	
	NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
	if (self.username && self.password)
	{
		[urlRequest setValue:[NSString stringWithFormat:@"Basic %@", [[[NSString stringWithFormat:@"%@:%@", self.username, self.password] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedString]] forHTTPHeaderField:@"Authorization"];	
	}

	if (jsonData)
    {
        [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [urlRequest setHTTPBody:jsonData];
    }

	switch (requestType) 
    {
		case UAGithubRepositoryCreateRequest:
		case UAGithubRepositoryDeleteConfirmationRequest:
        case UAGithubMilestoneCreateRequest:
		case UAGithubDeployKeyAddRequest:
		case UAGithubDeployKeyDeleteRequest:
		case UAGithubIssueCommentAddRequest:
        case UAGithubPublicKeyAddRequest:            
        case UAGithubRepositoryLabelAddRequest:
        case UAGithubIssueLabelAddRequest:            
        case UAGithubTreeCreateRequest:            
        case UAGithubBlobCreateRequest:            
        case UAGithubReferenceCreateRequest:
        case UAGithubRawCommitCreateRequest:
            
		{
			[urlRequest setHTTPMethod:@"POST"];
		}
			break;

		case UAGithubCollaboratorAddRequest:
        case UAGithubIssueLabelReplaceRequest:
        case UAGithubFollowRequest:
            
        {
            [urlRequest setHTTPMethod:@"PUT"];
        }
            break;
            
		case UAGithubRepositoryUpdateRequest:
        case UAGithubMilestoneUpdateRequest:
        case UAGithubIssueEditRequest:
        case UAGithubIssueCommentEditRequest:
        case UAGithubPublicKeyEditRequest:
        case UAGithubUserEditRequest:
        case UAGithubRepositoryLabelEditRequest:
        case UAGithubReferenceUpdateRequest:
            
        {
            [urlRequest setHTTPMethod:@"PATCH"];
        }
            break;
            
        case UAGithubMilestoneDeleteRequest:
        case UAGithubIssueDeleteRequest:
        case UAGithubIssueCommentDeleteRequest:
        case UAGithubUnfollowRequest:
        case UAGithubPublicKeyDeleteRequest:
		case UAGithubCollaboratorRemoveRequest:            
        case UAGithubRepositoryLabelRemoveRequest:
        case UAGithubIssueLabelRemoveRequest:
            
        {
            [urlRequest setHTTPMethod:@"DELETE"];
        }
            break;
            
		default:
			break;
	}
	
	UAGithubURLConnection *connection;
	connection = [[UAGithubURLConnection alloc] initWithRequest:urlRequest delegate:self requestType:requestType responseType:responseType];
	
	if (!connection) 
	{
		return nil;
	}
	else
	{ 
		[connections setObject:connection forKey:connection.identifier];
		[connection release];
	}
	
	return connection.identifier;
	
}


- (NSString *)sendRequest:(NSString *)path requestType:(UAGithubRequestType)requestType responseType:(UAGithubResponseType)responseType
{
    return [self sendRequest:path requestType:requestType responseType:responseType];
}


- (void)parseDataForConnection:(UAGithubURLConnection *)connection
{
	switch (connection.responseType) {
		case UAGithubRepositoriesResponse:
		case UAGithubRepositoryResponse:
			[[[UAGithubRepositoriesJSONParser alloc] initWithJSON:connection.data delegate:self connectionIdentifier:connection.identifier requestType:connection.requestType responseType:connection.responseType] autorelease];
			break;
        case UAGithubMilestonesResponse:
        case UAGithubMilestoneResponse:
            [[[UAGithubMilestonesJSONParser alloc] initWithJSON:connection.data delegate:self connectionIdentifier:connection.identifier requestType:connection.requestType responseType:connection.responseType] autorelease];
            break;
		case UAGithubIssuesResponse:
		case UAGithubIssueResponse:
			[[[UAGithubIssuesJSONParser alloc] initWithJSON:connection.data delegate:self connectionIdentifier:connection.identifier requestType:connection.requestType responseType:connection.responseType] autorelease];
			break;
		case UAGithubIssueCommentsResponse:
		case UAGithubIssueCommentResponse:
			[[[UAGithubIssueCommentsJSONParser alloc] initWithJSON:connection.data delegate:self connectionIdentifier:connection.identifier requestType:connection.requestType responseType:connection.responseType] autorelease];
			break;
		case UAGithubUsersResponse:
		case UAGithubUserResponse:
			[[[UAGithubUsersJSONParser alloc] initWithJSON:connection.data delegate:self connectionIdentifier:connection.identifier requestType:connection.requestType responseType:connection.responseType] autorelease];
			break;
		case UAGithubCommitsResponse:
		case UAGithubCommitResponse:
			[[[UAGithubCommitsJSONParser alloc] initWithJSON:connection.data delegate:self connectionIdentifier:connection.identifier requestType:connection.requestType responseType:connection.responseType] autorelease];
			break;
		case UAGithubRawBlobResponse:
			[delegate rawBlobReceived:connection.data forConnection:connection.identifier];
			break;
		case UAGithubCollaboratorsResponse:
		case UAGithubBlobsResponse:
		case UAGithubBlobResponse:
		case UAGithubIssueLabelsResponse:
		case UAGithubRepositoryLabelsResponse:
		case UAGithubDeployKeysResponse:
		case UAGithubRepositoryLanguageBreakdownResponse:
		case UAGithubTagsResponse:
		case UAGithubBranchesResponse:
        case UAGithubFollowingResponse:
        case UAGithubFollowersResponse:
		case UAGithubTreeResponse:
			[[[UAGithubSimpleJSONParser alloc] initWithJSON:connection.data delegate:self connectionIdentifier:connection.identifier requestType:connection.requestType responseType:connection.responseType] autorelease];
			break;
		default:
			break;
	}

}
	

#pragma mark Parser Delegate Methods

- (void)parsingSucceededForConnection:(NSString *)connectionIdentifier ofResponseType:(UAGithubResponseType)responseType withParsedObjects:(NSArray *)parsedObjects
{
	[delegate requestSucceeded:connectionIdentifier];
	
	switch (responseType) {
		case UAGithubRepositoriesResponse:
		case UAGithubRepositoryResponse:
			[delegate repositoriesReceived:parsedObjects forConnection:connectionIdentifier];
			break;
        case UAGithubMilestonesResponse:
        case UAGithubMilestoneResponse:
            [delegate milestonesReceived:parsedObjects forConnection:connectionIdentifier];
            break;
		case UAGithubIssuesResponse:
		case UAGithubIssueResponse:
			[delegate issuesReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubIssueCommentsResponse:
		case UAGithubIssueCommentResponse:
			[delegate issueCommentsReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubUsersResponse:
		case UAGithubUserResponse:
			[delegate usersReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubIssueLabelsResponse:
		case UAGithubRepositoryLabelsResponse:
			[delegate labelsReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubCommitsResponse:
		case UAGithubCommitResponse:
			[delegate commitsReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubBlobsResponse:
			[delegate blobsReceieved:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubBlobResponse:
			[delegate blobReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubCollaboratorsResponse:
			[delegate collaboratorsReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubDeployKeysResponse:
			[delegate deployKeysReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubRepositoryLanguageBreakdownResponse:
			[delegate languagesReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubTagsResponse:
			[delegate tagsReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubBranchesResponse:
			[delegate branchesReceived:parsedObjects forConnection:connectionIdentifier];
			break;
		case UAGithubTreeResponse:
			[delegate treeReceived:parsedObjects forConnection:connectionIdentifier];
			break;
        case UAGithubFollowingResponse:
			[delegate followingReceived:parsedObjects forConnection:connectionIdentifier];
			break;
        case UAGithubFollowersResponse:
			[delegate followersReceived:parsedObjects forConnection:connectionIdentifier];
			break;

		default:
			break;
	}
	
}


- (void)parsingFailedForConnection:(NSString *)connectionIdentifier ofResponseType:(UAGithubResponseType)responseType withError:(NSError *)parseError
{
	[delegate requestFailed:connectionIdentifier withError:parseError];	
}


#pragma mark Repositories

- (NSString *)repositoriesForUser:(NSString *)aUser includeWatched:(BOOL)watched
{
	return [self repositoriesForUser:aUser includeWatched:watched page:1];	
}

#pragma mark TODO watched repos?
- (NSString *)repositoriesForUser:(NSString *)aUser includeWatched:(BOOL)watched page:(int)page
{
	return [self sendRequest:[NSString stringWithFormat:@"users/%@/repos", aUser] requestType:UAGithubRepositoriesRequest responseType:UAGithubRepositoriesResponse];	
}


- (NSString *)repositories
{
    return [self sendRequest:@"user/repos" requestType:UAGithubRepositoriesRequest responseType:UAGithubRepositoriesResponse];
}

#pragma mark TODO check orgs is implemented elsewhere
- (NSString *)createRepositoryWithInfo:(NSDictionary *)infoDictionary
{
	return [self sendRequest:@"user/repos" requestType:UAGithubRepositoryCreateRequest responseType:UAGithubRepositoryResponse withParameters:infoDictionary];	
}


- (NSString *)repository:(NSString *)repositoryPath;
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@", repositoryPath] requestType:UAGithubRepositoryRequest responseType:UAGithubRepositoryResponse];	
}

/*
- (NSString *)searchRepositories:(NSString *)query
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/search/%@", [query encodedString]] requestType:UAGithubRepositoriesRequest responseType:UAGithubRepositoriesResponse];	 
}*/


- (NSString *)updateRepository:(NSString *)repositoryPath withInfo:(NSDictionary *)infoDictionary
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@", repositoryPath] requestType:UAGithubRepositoryUpdateRequest responseType:UAGithubRepositoryResponse withParameters:infoDictionary];
}


- (NSString *)contributorsForRepository:(NSString *)repositoryPath
{
   	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/contributitors", repositoryPath] requestType:UAGithubRepositoryContributorsRequest responseType:UAGithubUsersResponse];
}


- (NSString *)languageBreakdownForRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/languages", repositoryPath] requestType:UAGithubRepositoryLanguageBreakdownRequest responseType:UAGithubRepositoryLanguageBreakdownResponse];	
}


- (NSString *)teamsForRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/teams", repositoryPath] requestType:UAGithubRepositoryTeamsRequest responseType:UAGithubRepositoryTeamsResponse];
}


- (NSString *)annotatedTagsForRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/tags", repositoryPath] requestType:UAGithubTagsRequest responseType:UAGithubTagsResponse];	
}


- (NSString *)branchesForRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/branches", repositoryPath] requestType:UAGithubBranchesRequest responseType:UAGithubBranchesResponse];	
}


- (NSString *)collaboratorsForRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/collaborators", repositoryPath] requestType:UAGithubCollaboratorsRequest responseType:UAGithubCollaboratorsResponse];	
}

#pragma mark TODO Vomit. Returns 204 No Content if true, 404 if false.
- (NSString *)user:(NSString *)user isCollaboratorForRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/collaborators/%@", repositoryPath, user] requestType:UAGithubCollaboratorsRequest responseType:UAGithubNoContentResponse];
}


- (NSString *)addCollaborator:(NSString *)collaborator toRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/collaborators/%@", repositoryPath, collaborator] requestType:UAGithubCollaboratorAddRequest responseType:UAGithubCollaboratorsResponse];
}


- (NSString *)removeCollaborator:(NSString *)collaborator fromRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/collaborators/%@", repositoryPath, collaborator] requestType:UAGithubCollaboratorRemoveRequest responseType:UAGithubCollaboratorsResponse];
}


- (NSString *)downloadsForRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/downloads", repositoryPath] requestType:UAGithubDownloadsRequest responseType:UAGithubDownloadsResponse];
}


- (NSString *)download:(NSInteger)downloadId inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/downloads/%d", repositoryPath, downloadId] requestType:UAGithubDownloadRequest responseType:UAGithubDownloadResponse];
}


- (NSString *)addDownloadToRepository:(NSString *)repositoryPath withDictionary:(NSDictionary *)downloadDictionary
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/downloads", repositoryPath] requestType:UAGithubDownloadAddRequest responseType:UAGithubDownloadResponse withParameters:downloadDictionary];
}


- (NSString *)deleteDownload:(NSInteger)downloadId fromRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/downloads/%d", repositoryPath, downloadId] requestType:UAGithubDownloadDeleteRequest responseType:UAGithubNoContentResponse];
}


- (NSString *)forksForRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/forks", repositoryPath] requestType:UAGithubRepositoryForksRequest responseType:UAGithubRepositoriesResponse];
}


- (NSString *)forkRepository:(NSString *)repositoryPath inOrganization:(NSString *)org;
{
    if (org)
    {
        return [self sendRequest:[NSString stringWithFormat:@"repos/%@/forks", repositoryPath] requestType:UAGithubRepositoryForkRequest responseType:UAGithubRepositoryResponse withParameters:[NSDictionary dictionaryWithObject:org forKey:@"org"]];
    }
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/forks", repositoryPath] requestType:UAGithubRepositoryForkRequest responseType:UAGithubRepositoryResponse];
}


- (NSString *)forkRepository:(NSString *)repositoryPath
{
    return [self forkRepository:repositoryPath inOrganization:nil];
}


- (NSString *)deployKeysForRepository:(NSString *)repositoryName
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/keys", repositoryName] requestType:UAGithubDeployKeysRequest responseType:UAGithubDeployKeysResponse];
}


- (NSString *)deployKey:(NSInteger)keyId forRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/keys/%d", repositoryPath, keyId] requestType:UAGithubDeployKeyRequest responseType:UAGithubDeployKeyResponse];
}


- (NSString *)addDeployKey:(NSString *)keyData withTitle:(NSString *)keyTitle ToRepository:(NSString *)repositoryName
{
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:keyData, @"key", keyTitle, @"title", nil];
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/keys", repositoryName] requestType:UAGithubDeployKeyAddRequest responseType:UAGithubDeployKeysResponse withParameters:params];
    
}


- (NSString *)editDeployKey:(NSInteger)keyId inRepository:(NSString *)repositoryPath withDictionary:(NSDictionary *)keyDictionary
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/keys/%d", repositoryPath, keyId] requestType:UAGithubDeployKeyEditRequest responseType:UAGithubDeployKeyResponse withParameters:keyDictionary];
}


- (NSString *)removeDeployKey:(NSInteger)keyId fromRepository:(NSString *)repositoryName
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/keys/%d", repositoryName, keyId] requestType:UAGithubDeployKeyDeleteRequest responseType:UAGithubNoContentResponse];
    
}



- (NSString *)watchersForRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/watchers", repositoryPath] requestType:UAGithubUsersRequest responseType:UAGithubUsersResponse];
}


- (NSString *)watchedRepositoriesForUser:(NSString *)user
{
    return [self sendRequest:[NSString stringWithFormat:@"users/%@/watched", user] requestType:UAGithubRepositoriesRequest responseType:UAGithubRepositoriesResponse];
}


- (NSString *)watchedRepositories
{
    return [self sendRequest:@"user/watched" requestType:UAGithubRepositoriesRequest responseType:UAGithubRepositoriesResponse];
}


#pragma mark TODO Vomit again (204/404)
- (NSString *)repositoryIsWatched:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"user/watched/%@", repositoryPath] requestType:UAGithubRepositoryWatchingRequest responseType:UAGithubNoContentResponse];
}


- (NSString *)watchRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"user/watched/%@", repositoryPath] requestType:UAGithubRepositoryWatchRequest responseType:UAGithubNoContentResponse];	 
}


- (NSString *)unwatchRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"user/watched/%@", repositoryPath] requestType:UAGithubRepositoryUnwatchRequest responseType:UAGithubNoContentResponse];
}


- (NSString *)hooksForRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/hooks", repositoryPath] requestType:UAGithubRepositoryHooksRequest responseType:UAGithubRepositoryHooksResponse];
}


- (NSString *)hook:(NSInteger)hookId forRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/hooks/%d", repositoryPath, hookId] requestType:UAGithubRepositoryHookRequest responseType:UAGithubRepositoryHookResponse];
}


- (NSString *)addHook:(NSDictionary *)hookDictionary forRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/hooks", repositoryPath] requestType:UAGithubRepositoryHookAddRequest responseType:UAGithubRepositoryHookResponse];
}


- (NSString *)editHook:(NSInteger)hookId forRepository:(NSString *)repositoryPath withDictionary:(NSDictionary *)hookDictionary
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/hooks/%d", repositoryPath, hookId] requestType:UAGithubRepositoryHookEditRequest responseType:UAGithubRepositoryHookResponse withParameters:hookDictionary];
}


- (NSString *)testHook:(NSInteger)hookId forRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/hooks/%d", repositoryPath, hookId] requestType:UAGithubRepositoryHookTestRequest responseType:UAGithubNoContentResponse];
}


- (NSString *)removeHook:(NSInteger)hookId fromRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/hooks/%d", repositoryPath, hookId] requestType:UAGithubRepositoryHookDeleteRequest responseType:UAGithubNoContentResponse];
}


/*
- (NSString *)deleteRepository:(NSString *)repositoryName
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/delete/%@", repositoryName] requestType:UAGithubRepositoryDeleteRequest responseType:UAGithubDeleteRepositoryResponse];
}


- (NSString *)confirmDeletionOfRepository:(NSString *)repositoryName withToken:(NSString *)deleteToken
{
	NSDictionary *params = [NSDictionary dictionaryWithObject:deleteToken forKey:@"delete_token"];
	return [self sendRequest:[NSString stringWithFormat:@"repos/delete/%@", repositoryName] requestType:UAGithubRepositoryDeleteConfirmationRequest responseType:UAGithubDeleteRepositoryConfirmationResponse withParameters:params];
	
}


- (NSString *)privatiseRepository:(NSString *)repositoryName
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/set/private/%@", repositoryName] requestType:UAGithubRepositoryPrivatiseRequest responseType:UAGithubRepositoryResponse];	
}


- (NSString *)publiciseRepository:(NSString *)repositoryName
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/set/public/%@", repositoryName] requestType:UAGithubRepositoryPubliciseRequest responseType:UAGithubRepositoryResponse];
}


- (NSString *)pushableRepositories
{
	return [self sendRequest:@"repos/pushable" requestType:UAGithubRepositoriesRequest responseType:UAGithubRepositoriesResponse];	
}


- (NSString *)networkForRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/show/%@/network", repositoryPath] requestType:UAGithubRepositoriesRequest responseType:UAGithubRepositoriesResponse];	
}
*/

#pragma mark Milestones

- (NSString *)milestonesForRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/milestones", repositoryPath] requestType:UAGithubMilestonesRequest responseType:UAGithubMilestonesResponse];
}


- (NSString *)milestone:(NSInteger)milestoneNumber forRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/milestones/%d", repositoryPath, milestoneNumber] requestType:UAGithubMilestoneRequest responseType:UAGithubMilestoneResponse];
}


- (NSString *)createMilestoneWithInfo:(NSDictionary *)infoDictionary forRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/milestones", repositoryPath] requestType:UAGithubMilestoneCreateRequest responseType:UAGithubMilestoneResponse withParameters:infoDictionary];
}


- (NSString *)updateMilestone:(NSInteger)milestoneNumber forRepository:(NSString *)repositoryPath withInfo:(NSDictionary *)infoDictionary
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/milestones/%d", repositoryPath, milestoneNumber] requestType:UAGithubMilestoneUpdateRequest responseType:UAGithubMilestoneResponse withParameters:infoDictionary]; 
}


- (NSString *)deleteMilestone:(NSInteger)milestoneNumber forRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/milestones/%d", repositoryPath, milestoneNumber] requestType:UAGithubMilestoneDeleteRequest responseType:UAGithubMilestoneResponse];
}


#pragma mark Issues 

- (NSString *)issuesForRepository:(NSString *)repositoryPath withParameters:(NSDictionary *)parameters requestType:(UAGithubRequestType)requestType
{
	// Use UAGithubIssuesOpenRequest for open issues, UAGithubIssuesClosedRequest for closed issues, UAGithubIssuesRequest for all issues.

	switch (requestType) {
		case UAGithubIssuesOpenRequest:
			return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues?state=open", repositoryPath] requestType:UAGithubIssuesOpenRequest responseType:UAGithubIssuesResponse withParameters:parameters];
			break;
            
		case UAGithubIssuesClosedRequest:
			return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues?state=closed", repositoryPath] requestType:UAGithubIssuesClosedRequest responseType:UAGithubIssuesResponse withParameters:parameters];
			break;
            
        case UAGithubIssuesRequest:
		default:
            return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues", repositoryPath] requestType:UAGithubIssuesRequest responseType:UAGithubIssueResponse withParameters:parameters];
			break;
	}
	return nil;
}


- (NSString *)issue:(NSInteger)issueNumber inRepository:(NSString *)repositoryPath;
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/%d", repositoryPath, issueNumber] requestType:UAGithubIssueRequest responseType:UAGithubIssueResponse];	
}


- (NSString *)editIssue:(NSInteger)issueNumber inRepository:(NSString *)repositoryPath withDictionary:(NSDictionary *)issueDictionary;
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/%d", repositoryPath, issueNumber] requestType:UAGithubIssueEditRequest responseType:UAGithubIssueResponse withParameters:issueDictionary];	
}


- (NSString *)addIssueForRepository:(NSString *)repositoryPath withDictionary:(NSDictionary *)issueDictionary
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues", repositoryPath] requestType:UAGithubIssueAddRequest responseType:UAGithubIssueResponse withParameters:issueDictionary];	
}


- (NSString *)closeIssue:(NSString *)issuePath
{
	return [self sendRequest:[NSString stringWithFormat:@"issues/close/%@", issuePath] requestType:UAGithubIssueCloseRequest responseType:UAGithubIssueResponse];	
}


- (NSString *)reopenIssue:(NSString *)issuePath
{
	return [self sendRequest:[NSString stringWithFormat:@"issues/reopen/%@", issuePath] requestType:UAGithubIssueReopenRequest responseType:UAGithubIssueResponse];	
}


- (NSString *)deleteIssue:(NSInteger)issueNumber inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/%d", repositoryPath, issueNumber] requestType:UAGithubIssueRequest responseType:UAGithubIssueResponse];	
}

#pragma mark Labels

- (NSString *)labelsForRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/labels", repositoryPath] requestType:UAGithubRepositoryLabelsRequest responseType:UAGithubRepositoryLabelsResponse];	
}


- (NSString *)label:(NSString *)labelName inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/labels/%@", repositoryPath, labelName] requestType:UAGithubIssueLabelRequest responseType:UAGithubIssueLabelResponse];
}

- (NSString *)addLabelToRepository:(NSString *)repositoryPath withDictionary:(NSDictionary *)labelDictionary;
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/labels", repositoryPath] requestType:UAGithubRepositoryLabelAddRequest responseType:UAGithubIssueLabelsResponse withParameters:labelDictionary];	
}


- (NSString *)editLabel:(NSString *)labelName inRepository:(NSString *)repositoryPath withDictionary:(NSDictionary *)labelDictionary
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/labels/%@", repositoryPath, labelName] requestType:UAGithubRepositoryLabelEditRequest responseType:UAGithubRepositoryLabelResponse withParameters:labelDictionary];
}


- (NSString *)removeLabel:(NSString *)labelName fromRepository:(NSString *)repositoryPath;
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/labels/%@", repositoryPath, labelName] requestType:UAGithubRepositoryLabelRemoveRequest responseType:UAGithubNoContentResponse];	
}


/*- (NSString *)addLabel:(NSString *)label toIssue:(NSInteger)issueNumber inRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"issues/label/add/%@/%@/%d", repositoryPath, [label encodedString], issueNumber] requestType:UAGithubIssueLabelAddRequest responseType:UAGithubIssueLabelsResponse];	
}*/


- (NSString *)addLabels:(NSArray *)labels toIssue:(NSInteger)issueId inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/%d/labels", repositoryPath, issueId] requestType:UAGithubIssueLabelAddRequest responseType:UAGithubIssueLabelsResponse withParameters:labels];
}


- (NSString *)removeLabel:(NSString *)labelName fromIssue:(NSInteger)issueNumber inRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/%d/labels/%@", repositoryPath, issueNumber, labelName] requestType:UAGithubIssueLabelRemoveRequest responseType:UAGithubIssueLabelsResponse];	
}


// modify sendRequest... to take an id as final parameter. If passed an array, send through as is.

- (NSString *)replaceAllLabelsForIssue:(NSInteger)issueId inRepository:(NSString *)repositoryPath withLabels:(NSArray *)labels
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/%d/labels", repositoryPath, issueId] requestType:UAGithubIssueLabelReplaceRequest responseType:UAGithubIssueLabelsResponse withParameters:labels];
}


- (NSString *)labelsForIssue:(NSInteger)issueId inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/%d/labels", repositoryPath, issueId] requestType:UAGithubIssueLabelsRequest responseType:UAGithubIssueLabelsResponse];
}


- (NSString *)labelsForIssueInMilestone:(NSInteger)milestoneId inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/milestones/%d/labels", repositoryPath, milestoneId] requestType:UAGithubIssueLabelsRequest responseType:UAGithubIssueLabelsResponse];
}


#pragma mark Comments

- (NSString *)commentsForIssue:(NSInteger)issueNumber forRepository:(NSString *)repositoryPath
{
 	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/%d/comments", repositoryPath, issueNumber] requestType:UAGithubIssueCommentsRequest responseType:UAGithubIssueCommentsResponse];	
}


- (NSString *)issueComment:(NSInteger)commentNumber forRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/comments/%d", repositoryPath, commentNumber] requestType:UAGithubIssueCommentRequest responseType:UAGithubIssueCommentResponse];
}


- (NSString *)addComment:(NSString *)comment toIssue:(NSInteger)issueNumber forRepository:(NSString *)repositoryPath;
{
	NSDictionary *commentDictionary = [NSDictionary dictionaryWithObject:comment forKey:@"body"];
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/%d/comments", repositoryPath, issueNumber] requestType:UAGithubIssueCommentAddRequest responseType:UAGithubIssueCommentResponse withParameters:commentDictionary];
	
}


- (NSString *)editComment:(NSInteger)commentNumber forRepository:(NSString *)repositoryPath withBody:(NSString *)commentBody
{
    NSDictionary *commentDictionary = [NSDictionary dictionaryWithObject:commentBody forKey:@"body"];
    return [self sendRequest:[NSString stringWithFormat:@"repos/:user/:repo/issues/comments/:id", repositoryPath, commentNumber] requestType:UAGithubIssueCommentEditRequest responseType:UAGithubIssueCommentResponse withParameters:commentDictionary];
}


- (NSString *)deleteComment:(NSInteger)commentNumber forRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/issues/comments/%d", repositoryPath, commentNumber] requestType:UAGithubIssueCommentDeleteRequest responseType:UAGithubIssueCommentResponse];
}


#pragma mark Users

- (NSString *)user:(NSString *)user
{
	return [self sendRequest:[NSString stringWithFormat:@"users/%@", user] requestType:UAGithubUserRequest responseType:UAGithubUserResponse];	
}


- (NSString *)user
{
	return [self sendRequest:@"user" requestType:UAGithubUserRequest responseType:UAGithubUserResponse];	
}


- (NSString *)editUser:(NSDictionary *)userDictionary
{
    return [self sendRequest:@"user" requestType:UAGithubUserEditRequest responseType:UAGithubUserResponse withParameters:userDictionary];
}


#pragma mark TODO is in v3?
- (NSString *)searchUsers:(NSString *)query byEmail:(BOOL)email
{
	return [self sendRequest:[NSString stringWithFormat:@"user/%@/%@", email ? @"email" : @"search", query] requestType:UAGithubUserRequest responseType:UAGithubUsersResponse];	
}


- (NSString *)following:(NSString *)user
{
	return [self sendRequest:[NSString stringWithFormat:@"users/%@/following", user] requestType:UAGithubUserRequest responseType:UAGithubFollowingResponse];	    
}


- (NSString *)followers:(NSString *)user
{
	return [self sendRequest:[NSString stringWithFormat:@"users/%@/followers", user] requestType:UAGithubUserRequest responseType:UAGithubFollowersResponse];	    
    
}


- (NSString *)follow:(NSString *)user 
{
 	return [self sendRequest:[NSString stringWithFormat:@"user/following/%@", user] requestType:UAGithubFollowRequest responseType:UAGithubNoContentResponse];	    
   
}


- (NSString *)unfollow:(NSString *)user
{
 	return [self sendRequest:[NSString stringWithFormat:@"user/following/%@", user] requestType:UAGithubUnfollowRequest responseType:UAGithubNoContentResponse];	        
}


- (NSString *)publicKeys
{
    return [self sendRequest:@"user/keys" requestType:UAGithubPublicKeysRequest responseType:UAGithubPublicKeysResponse];
}


- (NSString *)publicKey:(NSInteger)keyId
{
    return [self sendRequest:[NSString stringWithFormat:@"user/keys/%d", keyId] requestType:UAGithubPublicKeyRequest responseType:UAGithubPublicKeyResponse];
}


- (NSString *)addPublicKey:(NSDictionary *)keyDictionary
{
    return [self sendRequest:@"user/keys" requestType:UAGithubPublicKeyAddRequest responseType:UAGithubPublicKeyResponse withParameters:keyDictionary];
}


- (NSString *)updatePublicKey:(NSInteger)keyId withInfo:(NSDictionary *)keyDictionary
{
    return [self sendRequest:[NSString stringWithFormat:@"user/keys/%d", keyId] requestType:UAGithubPublicKeyEditRequest responseType:UAGithubPublicKeyResponse withParameters:keyDictionary];
}


- (NSString *)deletePublicKey:(NSInteger)keyId
{
    return [self sendRequest:[NSString stringWithFormat:@"user/keys/%d", keyId] requestType:UAGithubPublicKeyDeleteRequest responseType:UAGithubNoContentResponse];
}


- (NSString *)createTagObject:(NSDictionary *)tagDictionary inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/tags", repositoryPath] requestType:UAGithubTagObjectCreateRequest responseType:UAGithubTagObjectResponse withParameters:tagDictionary];
}


#pragma mark Commits

- (NSString *)commitsForRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/commits", repositoryPath] requestType:UAGithubCommitsRequest responseType:UAGithubCommitsResponse];	
}


- (NSString *)commit:(NSString *)commitSha inRepository:(NSString *)repositoryPath
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/commits/%@", repositoryPath, commitSha] requestType:UAGithubCommitRequest responseType:UAGithubCommitResponse];	
}
	

#pragma mark Commit Comments

- (NSString *)commitCommentsForRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/comments", repositoryPath] requestType:UAGithubCommitCommentsRequest responseType:UAGithubCommitCommentsResponse];
}


- (NSString *)commitCommentsForCommit:(NSString *)sha inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/commits/%@/comments", repositoryPath, sha] requestType:UAGithubCommitCommentRequest responseType:UAGithubCommitCommentsResponse];
}


- (NSString *)addCommitComment:(NSDictionary *)commentDictionary forCommit:(NSString *)sha inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/commits/%@/comments", repositoryPath, sha] requestType:UAGithubCommitCommentAddRequest responseType:UAGithubCommitCommentResponse withParameters:commentDictionary];
}


- (NSString *)commitComment:(NSInteger)commentId inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/comments/%d", repositoryPath, commentId] requestType:UAGithubCommitCommentRequest responseType:UAGithubCommitCommentResponse];
}


- (NSString *)editCommitComment:(NSInteger)commentId inRepository:(NSString *)repositoryPath withDictionary:(NSDictionary *)infoDictionary
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/comments/%d", repositoryPath, commentId] requestType:UAGithubCommitCommentEditRequest responseType:UAGithubCommitCommentResponse withParameters:infoDictionary];
}


- (NSString *)deleteCommitComment:(NSInteger)commentId inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/comments/%d", repositoryPath, commentId] requestType:UAGithubCommitCommentDeleteRequest responseType:UAGithubNoContentResponse];
}


#pragma mark -
#pragma mark Git Database API
#pragma mark -
#pragma mark Trees

- (NSString *)tree:(NSString *)sha inRepository:(NSString *)repositoryPath recursive:(BOOL)recursive;
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/trees/%@%@", repositoryPath, sha, recursive ? @"?recursive=1" : @""] requestType:UAGithubTreeRequest responseType:UAGithubTreeResponse];	
}


- (NSString *)createTree:(NSDictionary *)treeDictionary inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/trees", repositoryPath] requestType:UAGithubTreeCreateRequest responseType:UAGithubTreeResponse withParameters:treeDictionary];
}


#pragma mark Blobs

- (NSString *)blobForSHA:(NSString *)sha inRepository:(NSString *)repositoryPath;
{
	return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/blobs/%@", repositoryPath, sha] requestType:UAGithubBlobRequest responseType:UAGithubBlobResponse];	
}


- (NSString *)createBlob:(NSDictionary *)blobDictionary inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/blobs", repositoryPath] requestType:UAGithubBlobCreateRequest responseType:UAGithubSHAResponse withParameters:blobDictionary];
}


#pragma mark References

- (NSString *)reference:(NSString *)reference inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/refs/%@", repositoryPath, reference] requestType:UAGithubReferenceRequest responseType:UAGithubReferenceResponse];
}


- (NSString *)referencesInRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/refs", repositoryPath] requestType:UAGithubReferencesRequest responseType:UAGithubReferencesResponse];
}


- (NSString *)tagsForRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/refs/tags", repositoryPath] requestType:UAGithubReferencesRequest responseType:UAGithubReferencesResponse];
}


- (NSString *)createReference:(NSDictionary *)refDictionary inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/refs", repositoryPath] requestType:UAGithubReferenceCreateRequest responseType:UAGithubReferenceResponse withParameters:refDictionary];
}


- (NSString *)updateReference:(NSString *)reference inRepository:(NSString *)repositoryPath withDictionary:(NSDictionary *)referenceDictionary
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/refs/%@", repositoryPath, reference] requestType:UAGithubReferenceUpdateRequest responseType:UAGithubReferenceResponse withParameters:referenceDictionary];
}


#pragma mark Tags

- (NSString *)tag:(NSString *)sha inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/tags/%@", repositoryPath, sha] requestType:UAGithubTagObjectRequest responseType:UAGithubTagObjectResponse];
}


#pragma mark Raw Commits

- (NSString *)rawCommit:(NSString *)commit inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/commits/%@", repositoryPath, commit] requestType:UAGithubRawCommitRequest responseType:UAGithubRawCommitResponse];
}


- (NSString *)createRawCommit:(NSDictionary *)commitDictionary inRepository:(NSString *)repositoryPath
{
    return [self sendRequest:[NSString stringWithFormat:@"repos/%@/git/commits", repositoryPath] requestType:UAGithubRawCommitCreateRequest responseType:UAGithubRawCommitResponse withParameters:commitDictionary];
}


#pragma mark -
#pragma mark NSURLConnection Delegate Methods
#pragma mark -

- (void)connection:(UAGithubURLConnection *)connection didFailWithError:(NSError *)error
{
	[self.connections removeObjectForKey:connection.identifier];
	
	if ([self isValidSelectorForDelegate:@selector(requestFailed:withError:)])
	{
		[delegate requestFailed:connection.identifier withError:error];
	}
			
	if ([self isValidSelectorForDelegate:@selector(connectionFinished:)])
	{
		[delegate connectionFinished:connection.identifier];
	}

}


- (void)connection:(UAGithubURLConnection *)connection didReceiveData:(NSData *)data
{
	[connection appendData:data];	
}


- (void)connection:(UAGithubURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[connection resetDataLength];
    
    // Get response code.
    NSHTTPURLResponse *resp = (NSHTTPURLResponse *)response;
    int statusCode = resp.statusCode;
	
	
	if ([[[resp allHeaderFields] allKeys] containsObject:@"X-Ratelimit-Remaining"] && [[[resp allHeaderFields] valueForKey:@"X-Ratelimit-Remaining"] isEqualToString:@"1"])
	{
		[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:UAGithubAPILimitReached object:nil]];
		[self.connections enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)
		 {
			 [(UAGithubURLConnection *)obj cancel];
		 }];
	}
		
	//If X-Ratelimit-Remaining == 0:
	//Add connection to list to retry
	//Get all remaining connections from self.connections and add to retry list
	//Post notification in 60s to allow new connections
    
    if (statusCode >= 400) {
        NSError *error = [NSError errorWithDomain:@"HTTP" code:statusCode userInfo:nil];
		if ([self isValidSelectorForDelegate:@selector(requestFailed:withError:)])
		{
			[delegate requestFailed:connection.identifier withError:error];
		}
        
        [connection cancel];
		NSString *connectionIdentifier = connection.identifier;
		[connections removeObjectForKey:connectionIdentifier];
		if ([self isValidSelectorForDelegate:@selector(connectionFinished:)])
		{
			[delegate connectionFinished:connectionIdentifier];
		}
		
    } 
	
}


- (void)connectionDidFinishLoading:(UAGithubURLConnection *)connection
{
	[self parseDataForConnection:connection];
	[self.connections removeObjectForKey:connection.identifier];
	if ([self isValidSelectorForDelegate:@selector(connectionFinished:)])
	{
		[delegate connectionFinished:connection.identifier];
	}
	
}


@end
