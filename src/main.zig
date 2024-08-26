const std = @import("std");

const ArgError = error{ URLNotSpecified, FilePathNotSpecified };
const MAX_SIZE = 4096;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args_iterator = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args_iterator.deinit();

    _ = args_iterator.next();
    const url = args_iterator.next() orelse return ArgError.URLNotSpecified;
    const file_path = args_iterator.next() orelse return ArgError.FilePathNotSpecified;

    const body: []u8 = try do_request(url);

    var formatted_buff: [MAX_SIZE]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&formatted_buff, "{s}", .{body});
    const file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
    defer file.close();

    try file.writeAll(formatted);
}

fn do_request(url: []const u8) ![]u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var client = std.http.Client{ .allocator = gpa.allocator() };
    defer client.deinit();

    var buf: [MAX_SIZE]u8 = undefined;
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &buf });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    var body_buf: [MAX_SIZE]u8 = undefined;
    _ = try req.readAll(&body_buf);
    const blength = req.response.content_length orelse return error.NoBodyLength;

    return body_buf[0..blength];
}
