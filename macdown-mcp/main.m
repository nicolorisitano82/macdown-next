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
//      macdownext-mcp --root ~/Verbali [--exclude <glob>…]
//                     [--append | --write] [--log <file> | --no-log]
//

#import <Foundation/Foundation.h>

#import "MDMCPDiary.h"
#import "MDMCPPerimeter.h"
#import "MDMCPServer.h"
#import "MDMCPTools.h"


static void MDUsage(void)
{
    fprintf(stderr,
        "uso: macdownext-mcp --root <cartella> [--exclude <glob>…]\n"
        "                    [--append | --write] [--log <file> | --no-log]\n"
        "\n"
        "Senza --root non parte: la cartella si dichiara, non si indovina,\n"
        "ed è una sola — due radici sono due modi di sbagliare un percorso.\n"
        "Di serie legge soltanto: cerca, leggi, elenca, indice dei titoli,\n"
        "chi cita, front matter, chi dichiara un campo.\n"
        "\n"
        "  --append  aggiunge in coda a un documento che esiste\n"
        "  --write   e in più crea documenti nuovi e sostituisce testo\n"
        "\n"
        "Non esiste uno strumento che cancella o che rinomina, e nessuno\n"
        "scrive un file intero sopra uno che c'era.\n"
        "\n"
        "Ogni chiamata finisce in ~/Library/Logs/MacDown Next/mcp.log,\n"
        "che non esce da questo Mac: --log la manda altrove, --no-log la\n"
        "spegne.\n");
}


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSURL *root = nil;
        NSMutableArray<NSString *> *excluded = [NSMutableArray array];
        MDMCPWriting writing = MDMCPReadOnly;
        NSURL *log = [MDMCPDiary standardFile];

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
            // The level is declared, like the root: the higher of two
            // flags would be a permission nobody meant to give.
            else if ([argument isEqualToString:@"--append"])
            {
                if (writing != MDMCPReadOnly)
                {
                    fprintf(stderr, "un livello solo: --append dopo "
                                    "--write\n");
                    return 2;
                }
                writing = MDMCPAppendOnly;
            }
            else if ([argument isEqualToString:@"--write"])
            {
                if (writing != MDMCPReadOnly)
                {
                    fprintf(stderr, "un livello solo: --write dopo "
                                    "--append\n");
                    return 2;
                }
                writing = MDMCPFullWriting;
            }
            else if ([argument isEqualToString:@"--log"] && i + 1 < argc)
            {
                log = [NSURL fileURLWithPath:
                    [@(argv[++i]) stringByExpandingTildeInPath]];
            }
            else if ([argument isEqualToString:@"--no-log"])
            {
                log = nil;
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
        perimeter.writing = writing;

        MDMCPDiary *diary = [[MDMCPDiary alloc] initWithFile:log];
        [diary noteTool:@"started"
                outcome:writing == MDMCPReadOnly ? @"read-only"
                    : (writing == MDMCPAppendOnly ? @"append" : @"write")
                   path:perimeter.root.path detail:@""];

        MDMCPTools *tools = [[MDMCPTools alloc] initWithPerimeter:perimeter];
        tools.diary = diary;
        MDMCPServer *server = [[MDMCPServer alloc] initWithTools:tools];
        [server runReading:[NSFileHandle fileHandleWithStandardInput]
                   writing:[NSFileHandle fileHandleWithStandardOutput]];
    }
    return 0;
}
