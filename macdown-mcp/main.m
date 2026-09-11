//
//  main.m
//  macdownext-mcp
//
//  A server that hands a folder of Markdown to whoever asks — Claude Code,
//  Claude Desktop, anything that speaks MCP — over standard input and
//  output, and that can do nothing else.
//
//  Started by the client, stopped by the client. The application does not
//  have to be running: what it reads is the folder.
//
//      macdownext-mcp --root ~/Verbali [--root …] [--exclude <glob>]
//

#import <Foundation/Foundation.h>

#import "MDMCPPerimeter.h"
#import "MDMCPServer.h"
#import "MDMCPTools.h"


static void MDUsage(void)
{
    fprintf(stderr,
        "uso: macdownext-mcp --root <cartella> [--exclude <glob>…]\n"
        "\n"
        "Senza --root non parte: la cartella si dichiara, non si indovina,\n"
        "ed è una sola — due radici sono due modi di sbagliare un percorso.\n"
        "Legge soltanto: cerca, leggi, elenca, indice dei titoli.\n");
}


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSURL *root = nil;
        NSMutableArray<NSString *> *excluded = [NSMutableArray array];

        for (int i = 1; i < argc; i++)
        {
            NSString *argument = @(argv[i]);
            if ([argument isEqualToString:@"--root"] && i + 1 < argc)
            {
                if (root)
                {
                    fprintf(stderr, "una radice sola: %s è la seconda\n",
                            argv[i + 1]);
                    return 2;
                }
                NSString *path = [@(argv[++i]) stringByExpandingTildeInPath];
                root = [NSURL fileURLWithPath:path];
            }
            else if ([argument isEqualToString:@"--exclude"] && i + 1 < argc)
            {
                [excluded addObject:@(argv[++i])];
            }
            else
            {
                MDUsage();
                return 2;
            }
        }

        if (!root)
        {
            MDUsage();
            return 2;
        }
        BOOL directory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:root.path
                                                  isDirectory:&directory]
                || !directory)
        {
            fprintf(stderr, "non è una cartella: %s\n", root.path.UTF8String);
            return 3;
        }

        MDMCPPerimeter *perimeter = [[MDMCPPerimeter alloc]
            initWithRoot:root];
        perimeter.excluded = excluded;
        perimeter.writing = MDMCPReadOnly;

        MDMCPServer *server = [[MDMCPServer alloc] initWithTools:
            [[MDMCPTools alloc] initWithPerimeter:perimeter]];
        [server runReading:[NSFileHandle fileHandleWithStandardInput]
                   writing:[NSFileHandle fileHandleWithStandardOutput]];
    }
    return 0;
}
