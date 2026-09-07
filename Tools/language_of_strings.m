//
//  language_of_strings.m
//  MacDown
//
//  Which language each line of standard input is in, one answer per line.
//  Used by Tools/check_translations.py so that the audit does not have to
//  guess from a word list: NaturalLanguage already knows.
//
//  Build:  clang -fobjc-arc -framework Foundation \
//              -framework NaturalLanguage -o language_of_strings \
//              Tools/language_of_strings.m
//
//  Lines are given escaped (\n for a newline) because one string may have
//  several lines in it.
//

#import <Foundation/Foundation.h>
#import <NaturalLanguage/NaturalLanguage.h>

int main(void)
{
    @autoreleasepool {
        NSFileHandle *in = [NSFileHandle fileHandleWithStandardInput];
        NSString *whole = [[NSString alloc]
            initWithData:[in readDataToEndOfFile]
                encoding:NSUTF8StringEncoding];

        for (NSString *line in [whole componentsSeparatedByString:@"\n"])
        {
            if (!line.length)
                continue;
            NSString *text = [line stringByReplacingOccurrencesOfString:@"\\n"
                                                             withString:@" "];
            // Placeholders and markup say nothing about the language.
            text = [[NSRegularExpression regularExpressionWithPattern:
                @"%[0-9.@a-zA-Z]+|[▸›·—…]" options:0 error:NULL]
                stringByReplacingMatchesInString:text options:0
                    range:NSMakeRange(0, text.length) withTemplate:@" "];
            text = [text stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if (text.length < 4)
            {
                // Too short to tell, and too short to matter either way.
                printf("und\n");
                continue;
            }
            NLLanguageRecognizer *recognizer =
                [[NLLanguageRecognizer alloc] init];
            recognizer.languageConstraints = @[NLLanguageEnglish,
                                               NLLanguageItalian];
            [recognizer processString:text];
            NSDictionary<NLLanguage, NSNumber *> *guesses =
                [recognizer languageHypothesesWithMaximum:2];
            double english = guesses[NLLanguageEnglish].doubleValue;
            double italian = guesses[NLLanguageItalian].doubleValue;
            if (italian > english)
                printf("it\n");
            else if (english > italian)
                printf("en\n");
            else
                printf("und\n");
        }
    }
    return 0;
}
