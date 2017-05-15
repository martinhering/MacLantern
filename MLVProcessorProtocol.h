/*
 * Copyright (C) 2017 Martin Hering
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Lesser Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef MLVProcessorProtocol_h
#define MLVProcessorProtocol_h

@protocol MLVProcessorProtocol

- (void) openFileWithURL:(NSURL*)url withReply:(void (^)(NSString *fileId, NSDictionary<NSString*, id>* attributes, NSError* error))reply;
- (void) closeFileWithId:(NSString*)fileId withReply:(void (^)(NSError* error))reply;

@end

#endif /* MLVProcessorProtocol_h */
