const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub const min = std.math.min;
pub const max = std.math.max;
pub const clamp = std.math.clamp;
pub const sin = std.math.sin;
pub const cos = std.math.cos;
pub const tan = std.math.tan;
pub const atan2 = std.math.atan2;
pub const sqrt = std.math.sqrt;

pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2 {
        return Vec2{.x = x, .y = y};
    }

    pub fn single(v: f32) Self {
        return Self{.x = v, .y = v};
    }

    pub fn add(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x + rhs.x,
            .y = lhs.y + rhs.y,
        };
    }

    pub fn sub(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x - rhs.x,
            .y = lhs.y - rhs.y,
        };
    }

    pub fn mul(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x * rhs.x,
            .y = lhs.y * rhs.y,
        };
    }

    pub fn div(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x / rhs.x,
            .y = lhs.y / rhs.y,
        };
    }

    pub fn sadd(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x + rhs,
            .y = lhs.y + rhs,
        };
    }

    pub fn ssub(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x - rhs,
            .y = lhs.y - rhs,
        };
    }

    pub fn smul(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x * rhs,
            .y = lhs.y * rhs,
        };
    }

    pub fn sdiv(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x / rhs,
            .y = lhs.y / rhs,
        };
    }

    pub fn dot(lhs: Self, rhs: Self) f32 {
        return lhs.x * rhs.x + lhs.y * rhs.y;
    }

    pub fn norm(lhs: Self) f32 {
        return sqrt(dot(lhs, lhs));
    }

    pub fn normalize(lhs: Self) Self {
        return sdiv(lhs, norm(lhs));
    }
};

pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    const Self = @This();

    pub fn init(x: f32, y: f32, z: f32) Self {
        return Self{.x = x, .y = y, .z = z};
    }

    pub fn single(v: f32) Self {
        return Self{.x = v, .y = v, .z = v};
    }

    pub fn add(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x + rhs.x,
            .y = lhs.y + rhs.y,
            .z = lhs.z + rhs.z,
        };
    }

    pub fn sub(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x - rhs.x,
            .y = lhs.y - rhs.y,
            .z = lhs.z - rhs.z,
        };
    }

    pub fn mul(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x * rhs.x,
            .y = lhs.y * rhs.y,
            .z = lhs.z * rhs.z,
        };
    }

    pub fn div(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x / rhs.x,
            .y = lhs.y / rhs.y,
            .z = lhs.z / rhs.z,
        };
    }

    pub fn sadd(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x + rhs,
            .y = lhs.y + rhs,
            .z = lhs.z + rhs,
        };
    }

    pub fn ssub(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x - rhs,
            .y = lhs.y - rhs,
            .z = lhs.z - rhs,
        };
    }

    pub fn smul(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x * rhs,
            .y = lhs.y * rhs,
            .z = lhs.z * rhs,
        };
    }

    pub fn sdiv(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x / rhs,
            .y = lhs.y / rhs,
            .z = lhs.z / rhs,
        };
    }

    pub fn dot(lhs: Self, rhs: Self) f32 {
        return lhs.x * rhs.x 
            + lhs.y * rhs.y 
            + lhs.z * rhs.z;
    }

    pub fn norm(lhs: Self) f32 {
        return sqrt(dot(lhs, lhs));
    }

    pub fn normalize(lhs: Self) Self {
        return sdiv(lhs, norm(lhs));
    }

    pub fn cross(lhs: Self, rhs: Self) Self {
        return Self{
            .x = (lhs.y * rhs.z) - (lhs.z * rhs.y),
            .y = (lhs.z * rhs.x) - (lhs.x * rhs.z),
            .z = (lhs.x * rhs.y) - (lhs.y * rhs.x),
        };
    }
};

pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    const Self = @This();

    pub const zero = Vec4.init(0, 0, 0, 0);
    pub const one = Vec4.single(1);

    pub fn init(x: f32, y: f32, z: f32, w: f32) Self {
        return Self{.x = x, .y = y, .z = z, .w = w};
    }

    pub fn single(v: f32) Self {
        return Self{.x = v, .y = v, .z = v, .w = v};
    }

    pub fn add(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x + rhs.x,
            .y = lhs.y + rhs.y,
            .z = lhs.z + rhs.z,
            .w = lhs.w + rhs.w,
        };
    }

    pub fn sub(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x - rhs.x,
            .y = lhs.y - rhs.y,
            .z = lhs.z - rhs.z,
            .w = lhs.w - rhs.w,
        };
    }

    pub fn mul(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x * rhs.x,
            .y = lhs.y * rhs.y,
            .z = lhs.z * rhs.z,
            .w = lhs.w * rhs.w,
        };
    }

    pub fn div(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x / rhs.x,
            .y = lhs.y / rhs.y,
            .z = lhs.z / rhs.z,
            .w = lhs.w / rhs.z,
        };
    }

    pub fn sadd(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x + rhs,
            .y = lhs.y + rhs,
            .z = lhs.z + rhs,
            .w = lhs.w + rhs,
        };
    }

    pub fn ssub(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x - rhs,
            .y = lhs.y - rhs,
            .z = lhs.z - rhs,
            .w = lhs.w - rhs,
        };
    }

    pub fn smul(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x * rhs,
            .y = lhs.y * rhs,
            .z = lhs.z * rhs,
            .w = lhs.w * rhs,
        };
    }

    pub fn sdiv(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x / rhs,
            .y = lhs.y / rhs,
            .z = lhs.z / rhs,
            .w = lhs.w / rhs,
        };
    }

    pub fn dot(lhs: Self, rhs: Self) f32 {
        return lhs.x * rhs.x 
            + lhs.y * rhs.y 
            + lhs.z * rhs.z
            + lhs.w * rhs.w;
    }

    pub fn norm(lhs: Self) f32 {
        return sqrt(dot(lhs, lhs));
    }

    pub fn normalize(lhs: Self) Self {
        return sdiv(lhs, norm(lhs));
    }
};

pub const Mat4 = extern struct {
    cols: [4]std.meta.Vector(4, f32),

    const Self = @This();

    pub const identity = diagonal(1);
    pub const zero = diagonal(0);

    pub fn diagonal(v: f32) Self {
        return Self{
            .cols = .{
                .{v, 0, 0, 0},
                .{0, v, 0, 0},
                .{0, 0, v, 0},
                .{0, 0, 0, v},
            }
        };
    }

    pub fn vmul(lhs: Self, rhs: Vec4) Vec4 {
        var result: Vec4 = undefined;

        result.x = lhs.cols[0][0] * rhs.x;
        result.x += lhs.cols[1][0] * rhs.y;
        result.x += lhs.cols[2][0] * rhs.z;
        result.x += lhs.cols[3][0] * rhs.w;

        result.y = lhs.cols[0][1] * rhs.x;
        result.y += lhs.cols[1][1] * rhs.y;
        result.y += lhs.cols[2][1] * rhs.z;
        result.y += lhs.cols[3][1] * rhs.w;

        result.z = lhs.cols[0][2] * rhs.x;
        result.z += lhs.cols[1][2] * rhs.y;
        result.z += lhs.cols[2][2] * rhs.z;
        result.z += lhs.cols[3][2] * rhs.w;

        result.w = lhs.cols[0][3] * rhs.x;
        result.w += lhs.cols[1][3] * rhs.y;
        result.w += lhs.cols[2][3] * rhs.z;
        result.w += lhs.cols[3][3] * rhs.w;

        return result;
    }

    pub fn mul(lhs: Self, rhs: Self) Self {
        var result: Self = undefined;
        inline for ([_]comptime_int{ 0, 1, 2, 3 }) |row| {
            inline for ([_]comptime_int{ 0, 1, 2, 3 }) |col| {
                var sum: f32 = 0.0;
                inline for ([_]comptime_int{ 0, 1, 2, 3 }) |i| {
                    sum += lhs.cols[i][row] * rhs.cols[col][i];
                }
                result.cols[col][row] = sum;
            }
        }
        return result;
    }

    pub fn batchMul(items: []const Self) Self {
        if (items.len == 0)
            return Self.identity;
        if (items.len == 1)
            return items[0];
        var value = items[0];
        var i: usize = 1;
        while (i < items.len) : (i += 1) {
            value = value.mul(items[i]);
        }
        return value;
    }

    pub fn transpose(lhs: Self) Self {
        var result: Self = undefined;
        inline for ([_]comptime_int{ 0, 1, 2, 3 }) |row| {
            inline for ([_]comptime_int{ 0, 1, 2, 3 }) |col| {
                result.cols[col][row] = lhs.cols[row][col];
            }
        }
        return result;
    }

    pub fn ortho(l: f32, r: f32, b: f32, t: f32, n: f32, f: f32) Self {
        return Self{
            .cols = .{
                .{  2.0/(r-l),    0,            0,          0 },
                .{  0,            2.0/(t-b),    0,          0 },
                .{  0,            0,            1.0/(f-n),  0 },
                .{ -(r+l)/(r-l), -(t+b)/(t-b), -n/(f-n),    1 },
            }
        };
    }

    pub fn perspective(fovy: f32, aspect: f32, n: f32, f: f32) Self {
        var c = 1.0 / tan(fovy / 2.0);
        return Self{
            .cols = .{
                .{c/aspect, 0,  0,                 0},
                .{0,        c,  0,                 0},
                .{0,        0, -(f+n)/(f-n),      -1},
                .{0,        0, -(2.0*f*n)/(f-n),   0},
            }
        };
    }

    pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Self {
        var f = center.sub(eye).normalize();
        var s = f.cross(up).normalize();
        var u = s.cross(f);

        var result = Self.identity;
        result.cols[0][0] = s.x;
        result.cols[1][0] = s.y;
        result.cols[2][0] = s.z;

        result.cols[0][1] = u.x;
        result.cols[1][1] = u.y;
        result.cols[2][1] = u.z;

        result.cols[0][2] = -f.x;
        result.cols[1][2] = -f.y;
        result.cols[2][2] = -f.z;

        result.cols[3][0] = -s.dot(eye);
        result.cols[3][1] = -u.dot(eye);
        result.cols[3][2] = f.dot(eye);
        return result;
    }
};

test "vec" {
    expectEqual(Vec4.single(2).dot(Vec4.zero), 0.0);
}

test "mat4" {
    var a = Mat4{
        .cols = .{
            .{1, 0, 2, 1},
            .{2, 1, 3, 1},
            .{1, 0, 4, 1},
            .{1, 1, 1, 1},
        }
    };

    var b = Mat4{
        .cols = .{
            .{2, 6, 1, 1},
            .{5, 7, 8, 1},
            .{1, 1, 1, 1},
            .{1, 1, 1, 1},
        }
    };

    var r = Mat4{
        .cols = .{
            .{16, 7, 27, 10},
            .{28, 8, 64, 21},
            .{5,  2, 10, 4 },
            .{5,  2, 10, 4 },
        }
    };

    var m1 = Mat4.batchMul(&[_]Mat4{a, b});
    var m2 = b.transpose().mul(a.transpose()).transpose();
    inline for ([_]comptime_int{ 0, 1, 2, 3 }) |col| {
        inline for ([_]comptime_int{ 0, 1, 2, 3 }) |row| {
            expectEqual(m1.cols[col][row], r.cols[col][row]);

            expectEqual(m1.cols[col][row], m2.cols[col][row]);
        }
    }

    var v1 = Vec4.init(2, 6, 1, 1);
    var rv1 = Vec4.init(16, 7, 27, 10);
    var v2 = a.vmul(v1);

    expectEqual(v2.x, rv1.x);
    expectEqual(v2.y, rv1.y);
    expectEqual(v2.z, rv1.z);
    expectEqual(v2.w, rv1.w);
}
