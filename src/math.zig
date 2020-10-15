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

    pub const zero = Vec2.init(0, 0);
    pub const one = Vec2.single(1);

    pub inline fn init(x: f32, y: f32) Vec2 {
        return Vec2{.x = x, .y = y};
    }

    pub inline fn single(v: f32) Self {
        return Self{.x = v, .y = v};
    }

    pub inline fn add(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x + rhs.x,
            .y = lhs.y + rhs.y,
        };
    }

    pub inline fn sub(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x - rhs.x,
            .y = lhs.y - rhs.y,
        };
    }

    pub inline fn mul(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x * rhs.x,
            .y = lhs.y * rhs.y,
        };
    }

    pub inline fn div(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x / rhs.x,
            .y = lhs.y / rhs.y,
        };
    }

    pub inline fn sadd(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x + rhs,
            .y = lhs.y + rhs,
        };
    }

    pub inline fn ssub(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x - rhs,
            .y = lhs.y - rhs,
        };
    }

    pub inline fn smul(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x * rhs,
            .y = lhs.y * rhs,
        };
    }

    pub inline fn sdiv(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x / rhs,
            .y = lhs.y / rhs,
        };
    }

    pub inline fn dot(lhs: Self, rhs: Self) f32 {
        return lhs.x * rhs.x + lhs.y * rhs.y;
    }

    pub inline fn norm(lhs: Self) f32 {
        return sqrt(dot(lhs, lhs));
    }

    pub inline fn normalize(lhs: Self) Self {
        return sdiv(lhs, norm(lhs));
    }
};

pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    const Self = @This();

    pub const zero = Vec3.init(0, 0, 0);
    pub const one = Vec3.single(1);

    pub inline fn init(x: f32, y: f32, z: f32) Self {
        return Self{.x = x, .y = y, .z = z};
    }

    pub inline fn single(v: f32) Self {
        return Self{.x = v, .y = v, .z = v};
    }

    pub inline fn add(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x + rhs.x,
            .y = lhs.y + rhs.y,
            .z = lhs.z + rhs.z,
        };
    }

    pub inline fn sub(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x - rhs.x,
            .y = lhs.y - rhs.y,
            .z = lhs.z - rhs.z,
        };
    }

    pub inline fn mul(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x * rhs.x,
            .y = lhs.y * rhs.y,
            .z = lhs.z * rhs.z,
        };
    }

    pub inline fn div(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x / rhs.x,
            .y = lhs.y / rhs.y,
            .z = lhs.z / rhs.z,
        };
    }

    pub inline fn sadd(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x + rhs,
            .y = lhs.y + rhs,
            .z = lhs.z + rhs,
        };
    }

    pub inline fn ssub(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x - rhs,
            .y = lhs.y - rhs,
            .z = lhs.z - rhs,
        };
    }

    pub inline fn smul(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x * rhs,
            .y = lhs.y * rhs,
            .z = lhs.z * rhs,
        };
    }

    pub inline fn sdiv(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x / rhs,
            .y = lhs.y / rhs,
            .z = lhs.z / rhs,
        };
    }

    pub inline fn dot(lhs: Self, rhs: Self) f32 {
        return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
    }

    pub inline fn norm(lhs: Self) f32 {
        return sqrt(dot(lhs, lhs));
    }

    pub inline fn normalize(lhs: Self) Self {
        return sdiv(lhs, norm(lhs));
    }

    pub inline fn cross(lhs: Self, rhs: Self) Self {
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

    pub inline fn init(x: f32, y: f32, z: f32, w: f32) Self {
        return Self{.x = x, .y = y, .z = z, .w = w};
    }

    pub inline fn single(v: f32) Self {
        return Self{.x = v, .y = v, .z = v, .w = v};
    }

    pub inline fn add(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x + rhs.x,
            .y = lhs.y + rhs.y,
            .z = lhs.z + rhs.z,
            .w = lhs.w + rhs.w,
        };
    }

    pub inline fn sub(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x - rhs.x,
            .y = lhs.y - rhs.y,
            .z = lhs.z - rhs.z,
            .w = lhs.w - rhs.w,
        };
    }

    pub inline fn mul(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x * rhs.x,
            .y = lhs.y * rhs.y,
            .z = lhs.z * rhs.z,
            .w = lhs.w * rhs.w,
        };
    }

    pub inline fn div(lhs: Self, rhs: Self) Self {
        return Self{
            .x = lhs.x / rhs.x,
            .y = lhs.y / rhs.y,
            .z = lhs.z / rhs.z,
            .w = lhs.w / rhs.z,
        };
    }

    pub inline fn sadd(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x + rhs,
            .y = lhs.y + rhs,
            .z = lhs.z + rhs,
            .w = lhs.w + rhs,
        };
    }

    pub inline fn ssub(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x - rhs,
            .y = lhs.y - rhs,
            .z = lhs.z - rhs,
            .w = lhs.w - rhs,
        };
    }

    pub inline fn smul(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x * rhs,
            .y = lhs.y * rhs,
            .z = lhs.z * rhs,
            .w = lhs.w * rhs,
        };
    }

    pub inline fn sdiv(lhs: Self, rhs: f32) Self {
        return Self{
            .x = lhs.x / rhs,
            .y = lhs.y / rhs,
            .z = lhs.z / rhs,
            .w = lhs.w / rhs,
        };
    }

    pub inline fn dot(lhs: Self, rhs: Self) f32 {
        return lhs.x * rhs.x 
            + lhs.y * rhs.y 
            + lhs.z * rhs.z
            + lhs.w * rhs.w;
    }

    pub inline fn norm(lhs: Self) f32 {
        return sqrt(dot(lhs, lhs));
    }

    pub inline fn normalize(lhs: Self) Self {
        return sdiv(lhs, norm(lhs));
    }
};

pub const Quat = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    const Self = @This();

    pub const identity = Self.init(0, 0, 0, 1);

    pub inline fn init(x: f32, y: f32, z: f32, w: f32) Self {
        return Self{.x = x, .y = y, .z = z, .w = w};
    }

    pub fn toMat4(self: *Self) Mat4 {
        var result = Mat4.identity;

        var xx: f32 = self.x * self.x;
        var yy: f32 = self.y * self.y;
        var zz: f32 = self.z * self.z;
        var xy: f32 = self.x * self.y;
        var xz: f32 = self.x * self.z;
        var yz: f32 = self.y * self.z;
        var wx: f32 = self.w * self.x;
        var wy: f32 = self.w * self.y;
        var wz: f32 = self.w * self.z;

        result.cols[0][0] = 1.0 - 2.0 * (yy + zz);
        result.cols[0][1] = 2.0 * (xy + wz);
        result.cols[0][2] = 2.0 * (xz - wy);

        result.cols[1][0] = 2.0 * (xy - wz);
        result.cols[1][1] = 1.0 - 2.0 * (xx + zz);
        result.cols[1][2] = 2.0 * (yz + wx);

        result.cols[2][0] = 2.0 * (xz + wy);
        result.cols[2][1] = 2.0 * (yz - wx);
        result.cols[2][2] = 1.0 - 2.0 * (xx + yy);

        return result;
    }
};

pub const Mat4 = extern struct {
    cols: [4]ColType,

    const ColType = std.meta.Vector(4, f32);
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

    pub fn translation(pos: Vec3) Self {
        return Mat4{
            .cols = .{
                .{ 1,     0,     0,     0 },
                .{ 0,     1,     0,     0 },
                .{ 0,     0,     1,     0 },
                .{ pos.x, pos.y, pos.z, 1 },
            },
        };
    }

    pub fn scaling(vec: Vec3) Self {
        return Mat4{
            .cols = .{
                .{ vec.x, 0,     0,     0 },
                .{ 0,     vec.y, 0,     0 },
                .{ 0,     0,     vec.z, 0 },
                .{ 0,     0,     0,     1 },
            }
        };
    }

    pub fn translate(rhs: Self, vec: Vec3) Self {
        return Self.translation(vec).mul(rhs);
    }

    pub fn scale(rhs: Self, vec: Vec3) Self {
        return Self.scaling(vec).mul(rhs);
    }

    inline fn smulCol(col: ColType, v: f32) ColType {
        return ColType{
            col[0] * v,
            col[1] * v,
            col[2] * v,
            col[3] * v,
        };
    }

    pub fn rotate(mat: Mat4, angle: f32, axis: Vec3) Self {
        var c = cos(angle);
        var s = sin(angle);

        var norm_axis = axis.normalize();
        var temp = norm_axis.smul(1 - c);

        var rot = Mat4.zero;
        rot.cols[0][0] = c + temp.x * norm_axis.x;
        rot.cols[0][1] = temp.x * norm_axis.y + s * norm_axis.z;
        rot.cols[0][2] = temp.x * norm_axis.z - s * norm_axis.y;

        rot.cols[1][0] = temp.y * norm_axis.x - s * norm_axis.z;
        rot.cols[1][1] = c + temp.y * norm_axis.y;
        rot.cols[1][2] = temp.y * norm_axis.z + s * norm_axis.x;

        rot.cols[2][0] = temp.z * norm_axis.x + s * norm_axis.y;
        rot.cols[2][1] = temp.z * norm_axis.y - s * norm_axis.x;
        rot.cols[2][2] = c + temp.z * norm_axis.z;

        return Mat4{
            .cols = .{
                smulCol(mat.cols[0], rot.cols[0][0]) +
                smulCol(mat.cols[1], rot.cols[0][1]) +
                smulCol(mat.cols[2], rot.cols[0][2]),

                smulCol(mat.cols[0], rot.cols[1][0]) +
                smulCol(mat.cols[1], rot.cols[1][1]) +
                smulCol(mat.cols[2], rot.cols[1][2]),

                smulCol(mat.cols[0], rot.cols[2][0]) +
                smulCol(mat.cols[1], rot.cols[2][1]) +
                smulCol(mat.cols[2], rot.cols[2][2]),

                mat.cols[3],
            },
        };
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

test "rotate" {
    var m = Mat4.identity;
    var new = m.rotate(20, Vec3.init(1, 0, 0)).translate(Vec3.init(1, 2, 3)).scale(Vec3.init(2, 2, 2));
    _ = Mat4.lookAt(Vec3.single(0), Vec3.single(0), Vec3.single(0));
}
