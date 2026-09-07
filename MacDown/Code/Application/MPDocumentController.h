//
//  MPDocumentController.h
//  MacDown
//
//  Opening the two containers: .textbundle and .textpack.
//
//  A textbundle is a folder with one text file in it, so the document this
//  application opens is that file — everything else then works without
//  knowing about the container: the pictures beside it resolve, saving
//  writes back into the bundle, and the preview draws what it always drew.
//  A textpack is unpacked first, next to itself.
//

#import <Cocoa/Cocoa.h>


@interface MPDocumentController : NSDocumentController
@end
