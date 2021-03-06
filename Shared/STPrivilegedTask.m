/*
 
 STPrivilegedTask - NSTask-like wrapper around AuthorizationExecuteWithPrivileges
 Copyright (C) 2009 Sveinbjorn Thordarson <sveinbjornt@gmail.com>
 
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 
 */

#import "STPrivilegedTask.h"
#import <stdio.h>
#import <unistd.h>

@implementation STPrivilegedTask

- (id)init
{
	if ((self = [super init])) 
	{
		launchPath = [[NSString alloc] initWithString: @""];
		cwd = [[NSString alloc] initWithString: [[NSFileManager defaultManager] currentDirectoryPath]];
		arguments = [[NSArray alloc] init];
		isRunning = NO;
		outputFileHandle = NULL;
    }
    return self;
}

-(void)dealloc
{	
	if (arguments != NULL)
		[arguments release];

	if (cwd != NULL)
		[cwd release];
	
	if (outputFileHandle != NULL)
		[outputFileHandle release];

	if (launchPath != NULL)
		[launchPath release];
	
	[super dealloc];
}

-(id)initWithLaunchPath: (NSString *)path arguments:  (NSArray *)args
{
	if ((self = [self init]))
	{
		[self setLaunchPath: path];
		[self setArguments: args];
	}
	return self;
}

#pragma mark -

+ (STPrivilegedTask *)launchedPrivilegedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)args
{
	STPrivilegedTask *task = [[[STPrivilegedTask alloc] initWithLaunchPath: path arguments: args] autorelease];
	[task launch];
	[task waitUntilExit];
	return task;
}

#pragma mark -

- (NSArray *)arguments
{
	return arguments;
}

- (NSString *)currentDirectoryPath;
{
	return cwd;
}

- (BOOL)isRunning
{
	return isRunning;
}

- (NSString *)launchPath
{
	return launchPath;
}

- (int)processIdentifier
{
	return pid;
}

- (int)terminationStatus
{
	return terminationStatus;
}

- (NSFileHandle *)outputFileHandle;
{
	return outputFileHandle;
}

#pragma mark -

- (void)setArguments:(NSArray *)args
{
	if (arguments != NULL)
		[arguments release];
	arguments = [[NSArray alloc] initWithArray: args];
}

- (void)setCurrentDirectoryPath:(NSString *)path
{
	cwd = [[NSString alloc] initWithString: path];
}

- (void)setLaunchPath:(NSString *)path
{
	launchPath = [[NSString alloc] initWithString: path];
}

# pragma mark -

// return 0 for success
- (int) launch
{
	OSStatus				err = noErr;
    short					i;
	const char				*toolPath = [launchPath fileSystemRepresentation];
	
	AuthorizationRef		authorizationRef;
	AuthorizationItem		myItems = {kAuthorizationRightExecute, strlen(toolPath), &toolPath, 0};
	AuthorizationRights		myRights = {1, &myItems};
	AuthorizationFlags		flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
	
	unsigned int			argumentsCount = [arguments count];
	char					*args[argumentsCount + 1];
	FILE					*outputFile;

	// Use Apple's Authentication Manager APIs to get an Authorization Reference
	// These Apple APIs are quite possibly the most horrible of the Mac OS X APIs
	
	// create authorization reference
    err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    if (err != errAuthorizationSuccess)
		return err;
	
	// pre-authorize the privileged operation
	err = AuthorizationCopyRights(authorizationRef, &myRights, kAuthorizationEmptyEnvironment, flags, NULL);
	if (err != errAuthorizationSuccess) 
		return err;
	
	// OK, at this point we have received authorization for the task.
	// Let's prepare to launch it
	
	// first, construct an array of c strings from NSArray w. arguments
	for (i = 0; i < argumentsCount; i++) 
	{
		NSString *theString = [arguments objectAtIndex:i];
		unsigned int stringLength = [theString length];
		
		args[i] = malloc((stringLength + 1) * sizeof(char));
		snprintf(args[i], stringLength + 1, "%s", [theString fileSystemRepresentation]);
	}
	args[argumentsCount] = NULL;
	
	// change to the current dir specified
	char *prevCwd = (char *)getcwd(nil, 0);
	chdir([cwd fileSystemRepresentation]);
	
	//use Authorization Reference to execute script with privileges
    err = AuthorizationExecuteWithPrivileges(authorizationRef, [launchPath fileSystemRepresentation], kAuthorizationFlagDefaults, args, &outputFile);
	//pid_t thePid = 0;
	//err = AuthorizationExecuteWithPrivilegesStdErrAndPid(authorizationRef, [launchPath fileSystemRepresentation], kAuthorizationFlagDefaults, args, &outputFile, &outputFile, &thePid);
	
	// OK, now we're done executing
	// let's change back to old dir
	chdir(prevCwd);
	
	// dispose of the argument strings
	for (i = 0; i < argumentsCount; i++)
		free(args[i]);
	
	// destroy the auth ref
	AuthorizationFree(authorizationRef, kAuthorizationFlagDefaults);
	
	// we return if execution failed
	if (err != errAuthorizationSuccess) 
		return err;
	else
		isRunning = YES;
	
	// get file handle for the command output
	outputFileHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileno(outputFile) closeOnDealloc: YES];
	//pid = thePid;
	pid = fcntl(fileno(outputFile), F_GETOWN, 0);
	
	// start monitoring task
	checkStatusTimer = [NSTimer scheduledTimerWithTimeInterval: 0.10 target: self selector:@selector(_checkTaskStatus) userInfo: nil repeats: YES];
		
	return err;
}

- (void)terminate
{
	// This doesn't work without a PID, and we can't get one.  Stupid Security API
	/*	int ret = kill(pid, SIGKILL);
	 
	 if (ret != 0)
	 NSLog(@"Error %d", errno);*/
}

// hang until task is done
- (void)waitUntilExit
{
	//int mypid = 
	waitpid([self processIdentifier], &terminationStatus, 0);
	isRunning = NO;
}

#pragma mark -

// check if privileged task is still running
- (void)_checkTaskStatus
{	
	// see if task has terminated
    int mypid = waitpid([self processIdentifier], &terminationStatus, WNOHANG);
    if (mypid != 0)
	{
		isRunning = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName: STPrivilegedTaskDidTerminateNotification object:self];
		[checkStatusTimer invalidate];
	}
}

@end

/*
 *
 * Add the Standard err Pipe and Pid support to AuthorizationExecuteWithPrivileges()
 * method
 *
 * @Author: Miklós Fazekas
 * Modified Aug 10 2010 by Sveinbjorn Thordarson
 *
 */


/*static OSStatus AuthorizationExecuteWithPrivilegesStdErrAndPid (
																AuthorizationRef authorization,
																const char *pathToTool,
																AuthorizationFlags options,
																char * const *arguments,
																FILE **communicationsPipe,
																FILE **errPipe,
																pid_t* processid
																)
{
	// get the Apple-approved secure temp directory
	NSString *tempFileTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent: TMP_STDERR_TEMPLATE];
	
	// copy it into a C string
	const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
	char *stderrpath = (char *)malloc(strlen(tempFileTemplateCString) + 1);
	strcpy(stderrpath, tempFileTemplateCString);
	
	printf("%s\n", stderrpath);
	
	// this is the command, it echoes pid and directs stderr output to pipe before running the tool w. args
	const char *commandtemplate = "echo $$; \"$@\" 2>%s";
    
	if (communicationsPipe == errPipe)
		commandtemplate = "echo $$; \"$@\" 2>1";
    else if (errPipe == 0)
		commandtemplate = "echo $$; \"$@\"";
    
	char		command[1024];
	char		**args;
	OSStatus	result;
	int			argcount = 0;
	int			i;
	int			stderrfd = 0;
	FILE		*commPipe = 0;
	
	// First, create temporary file for stderr
    if (errPipe) 
	{
		// create temp file
        stderrfd = mkstemp(stderrpath);
		
        // close and remove it
        close(stderrfd); 
		unlink(stderrpath);
				
		// create a pipe on the path of the temp file
        if (mkfifo(stderrpath,S_IRWXU | S_IRWXG) != 0)
		{
            fprintf(stderr,"Error mkfifo:%d\n", errno);
            return errAuthorizationInternal;
        }
		
        if (stderrfd < 0)
            return errAuthorizationInternal;
    }
	
	// Create command to be executed
	for (argcount = 0; arguments[argcount] != 0; ++argcount) {}
	args = (char**)malloc (sizeof(char*)*(argcount + 5));
	args[0] = "-c";
	snprintf (command, sizeof (command), commandtemplate, stderrpath);
	args[1] = command;
	args[2] = "";
	args[3] = (char*)pathToTool;
	for (i = 0; i < argcount; ++i) {
		args[i+4] = arguments[i];
	}
	args[argcount+4] = 0;
	
    // for debugging: log the executed command
	printf ("Exec:\n%s", "/bin/sh"); for (i = 0; args[i] != 0; ++i) { printf (" \"%s\"", args[i]); } printf ("\n");
	
	// Execute command
	result = AuthorizationExecuteWithPrivileges(authorization, "/bin/sh",  options, args, &commPipe );
	if (result != noErr) 
	{
		unlink (stderrpath);
		return result;
	}
	
	// Read the first line of stdout => it's the pid
	{
		int stdoutfd = fileno (commPipe);
		char pidnum[1024];
		pid_t pid = 0;
		int i = 0;
		char ch = 0;
		
		while ((read(stdoutfd, &ch, sizeof(ch)) == 1) && (ch != '\n') && (i < sizeof(pidnum))) 
		{
			pidnum[i++] = ch;
		}
		pidnum[i] = 0;
		
		if (ch != '\n') 
		{
			// we shouldn't get there
			unlink (stderrpath);
			return errAuthorizationInternal;
		}
		sscanf(pidnum, "%d", &pid);
		if (processid) 
		{
			*processid = pid;
		}
		NSLog(@"Have PID %d", pid);
	}
	
	// 
	if (errPipe) {
        stderrfd = open(stderrpath, O_RDONLY, 0);
        // *errPipe = fdopen(stderrfd, "r");
         //Now it's safe to unlink the stderr file, as the opened handle will be still valid
        unlink (stderrpath);
	} else {
		unlink(stderrpath);
	}
	
	if (communicationsPipe) 
		*communicationsPipe = commPipe;
	else
		fclose (commPipe);
	
	NSLog(@"AuthExecNew function over");
	
	return noErr;
}*/