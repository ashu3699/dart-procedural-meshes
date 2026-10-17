import 'dart:math' as math;
import 'dart:typed_data';

/// A triangle mesh with per-vertex and per-face normals — everything is built
/// procedurally so the app ships zero model assets.
class MeshData {
  MeshData({
    required this.positions,
    required this.faces,
    required this.vertexNormals,
  }) : faceNormals = _computeFaceNormals(positions, faces);

  /// 3 floats per vertex (x, y, z).
  final Float32List positions;

  /// 3 indices per triangle.
  final Uint32List faces;

  /// 3 floats per vertex.
  final Float32List vertexNormals;

  /// 3 floats per triangle.
  final Float32List faceNormals;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => faces.length ~/ 3;

  static Float32List _computeFaceNormals(Float32List p, Uint32List f) {
    final normals = Float32List(f.length);
    for (var i = 0; i < f.length; i += 3) {
      final a = f[i] * 3;
      final b = f[i + 1] * 3;
      final c = f[i + 2] * 3;
      final ux = p[b] - p[a];
      final uy = p[b + 1] - p[a + 1];
      final uz = p[b + 2] - p[a + 2];
      final vx = p[c] - p[a];
      final vy = p[c + 1] - p[a + 1];
      final vz = p[c + 2] - p[a + 2];
      var nx = uy * vz - uz * vy;
      var ny = uz * vx - ux * vz;
      var nz = ux * vy - uy * vx;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 1e-9) {
        nx /= len;
        ny /= len;
        nz /= len;
      }
      normals[i] = nx;
      normals[i + 1] = ny;
      normals[i + 2] = nz;
    }
    return normals;
  }

  /// Welds raw lists into a mesh, flipping any triangle whose winding disagrees
  /// with the averaged vertex normals so backface culling is always correct.
  static MeshData fromParts(
    List<double> positions,
    List<double> vertexNormals,
    List<int> faces,
  ) {
    for (var f = 0; f < faces.length; f += 3) {
      final a = faces[f] * 3;
      final b = faces[f + 1] * 3;
      final c = faces[f + 2] * 3;
      final ux = positions[b] - positions[a];
      final uy = positions[b + 1] - positions[a + 1];
      final uz = positions[b + 2] - positions[a + 2];
      final vx = positions[c] - positions[a];
      final vy = positions[c + 1] - positions[a + 1];
      final vz = positions[c + 2] - positions[a + 2];
      final nx = uy * vz - uz * vy;
      final ny = uz * vx - ux * vz;
      final nz = ux * vy - uy * vx;
      final gx = (vertexNormals[a] + vertexNormals[b] + vertexNormals[c]) / 3;
      final gy =
          (vertexNormals[a + 1] + vertexNormals[b + 1] + vertexNormals[c + 1]) /
          3;
      final gz =
          (vertexNormals[a + 2] + vertexNormals[b + 2] + vertexNormals[c + 2]) /
          3;
      if (nx * gx + ny * gy + nz * gz < 0) {
        final swap = faces[f + 1];
        faces[f + 1] = faces[f + 2];
        faces[f + 2] = swap;
      }
    }
    return MeshData(
      positions: Float32List.fromList(positions),
      faces: Uint32List.fromList(faces),
      vertexNormals: Float32List.fromList(vertexNormals),
    );
  }

  /// Recursive icosahedron subdivision — smooth normals come free since every
  /// vertex is normalised to the unit sphere.
  static MeshData icosphere([int subdivisions = 2]) {
    const double t = 1.618033988749895;
    final verts = <double>[
      -1, t, 0, 1, t, 0, -1, -t, 0, 1, -t, 0, //
      0, -1, t, 0, 1, t, 0, -1, -t, 0, 1, -t, //
      t, 0, -1, t, 0, 1, -t, 0, -1, -t, 0, 1,
    ];
    for (var i = 0; i < verts.length; i += 3) {
      final len = math.sqrt(
        verts[i] * verts[i] +
            verts[i + 1] * verts[i + 1] +
            verts[i + 2] * verts[i + 2],
      );
      verts[i] /= len;
      verts[i + 1] /= len;
      verts[i + 2] /= len;
    }
    var faces = <int>[
      0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, //
      1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, //
      3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, //
      4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1,
    ];

    final midCache = <int, int>{};
    int midpoint(int a, int b) {
      final key = a < b ? (a << 20) | b : (b << 20) | a;
      final cached = midCache[key];
      if (cached != null) return cached;
      final ia = a * 3;
      final ib = b * 3;
      var x = (verts[ia] + verts[ib]) / 2;
      var y = (verts[ia + 1] + verts[ib + 1]) / 2;
      var z = (verts[ia + 2] + verts[ib + 2]) / 2;
      final len = math.sqrt(x * x + y * y + z * z);
      x /= len;
      y /= len;
      z /= len;
      final index = verts.length ~/ 3;
      verts.addAll([x, y, z]);
      midCache[key] = index;
      return index;
    }

    for (var s = 0; s < subdivisions; s++) {
      final next = <int>[];
      for (var f = 0; f < faces.length; f += 3) {
        final a = faces[f];
        final b = faces[f + 1];
        final c = faces[f + 2];
        final ab = midpoint(a, b);
        final bc = midpoint(b, c);
        final ca = midpoint(c, a);
        next.addAll([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]);
      }
      faces = next;
    }

    return fromParts(verts, List<double>.from(verts), faces);
  }

  /// Standard torus with analytic normals.
  static MeshData torus({
    int major = 36,
    int minor = 18,
    double ringRadius = 0.92,
    double tubeRadius = 0.4,
    double scale = 0.92,
  }) {
    final positions = <double>[];
    final normals = <double>[];
    for (var i = 0; i < major; i++) {
      final u = 2 * math.pi * i / major;
      final cu = math.cos(u);
      final su = math.sin(u);
      for (var j = 0; j < minor; j++) {
        final v = 2 * math.pi * j / minor;
        final cv = math.cos(v);
        final sv = math.sin(v);
        positions.addAll([
          (ringRadius + tubeRadius * cv) * cu * scale,
          tubeRadius * sv * scale,
          (ringRadius + tubeRadius * cv) * su * scale,
        ]);
        normals.addAll([cv * cu, sv, cv * su]);
      }
    }
    final faces = <int>[];
    for (var i = 0; i < major; i++) {
      final i2 = (i + 1) % major;
      for (var j = 0; j < minor; j++) {
        final j2 = (j + 1) % minor;
        final a = i * minor + j;
        final b = i2 * minor + j;
        final c = i2 * minor + j2;
        final d = i * minor + j2;
        faces.addAll([a, b, c, a, c, d]);
      }
    }
    return fromParts(positions, normals, faces);
  }

  /// Trefoil torus-knot tube swept with parallel-transport frames.
  static MeshData torusKnot({
    int steps = 110,
    int tube = 10,
    double tubeRadius = 0.055,
    double scale = 0.42,
  }) {
    List<double> curve(double t) => [
      math.sin(t) + 2 * math.sin(2 * t),
      math.cos(t) - 2 * math.cos(2 * t),
      -math.sin(3 * t),
    ];

    final positions = <double>[];
    final normals = <double>[];
    var previousNormal = <double>[];

    for (var i = 0; i < steps; i++) {
      final t = 2 * math.pi * i / steps;
      final p = curve(t);
      final ahead = curve(t + 0.001);
      final behind = curve(t - 0.001);
      var tx = ahead[0] - behind[0];
      var ty = ahead[1] - behind[1];
      var tz = ahead[2] - behind[2];
      final tl = math.sqrt(tx * tx + ty * ty + tz * tz);
      tx /= tl;
      ty /= tl;
      tz /= tl;

      List<double> normal;
      if (previousNormal.isEmpty) {
        final refZ = tz.abs() < 0.9;
        normal = [refZ ? 0.0 : 1.0, refZ ? 1.0 : 0.0, 0.0];
      } else {
        final dot =
            previousNormal[0] * tx +
            previousNormal[1] * ty +
            previousNormal[2] * tz;
        normal = [
          previousNormal[0] - tx * dot,
          previousNormal[1] - ty * dot,
          previousNormal[2] - tz * dot,
        ];
      }
      var nl = math.sqrt(
        normal[0] * normal[0] + normal[1] * normal[1] + normal[2] * normal[2],
      );
      if (nl < 1e-6) {
        normal = [1.0, 0.0, 0.0];
        nl = 1.0;
      }
      normal = [normal[0] / nl, normal[1] / nl, normal[2] / nl];
      previousNormal = normal;

      final bx = ty * normal[2] - tz * normal[1];
      final by = tz * normal[0] - tx * normal[2];
      final bz = tx * normal[1] - ty * normal[0];

      for (var j = 0; j < tube; j++) {
        final a = 2 * math.pi * j / tube;
        final ca = math.cos(a);
        final sa = math.sin(a);
        final nx = normal[0] * ca + bx * sa;
        final ny = normal[1] * ca + by * sa;
        final nz = normal[2] * ca + bz * sa;
        positions.addAll([
          (p[0] + nx * tubeRadius) * scale,
          (p[1] + ny * tubeRadius) * scale,
          (p[2] + nz * tubeRadius) * scale,
        ]);
        normals.addAll([nx, ny, nz]);
      }
    }

    final faces = <int>[];
    for (var i = 0; i < steps; i++) {
      final i2 = (i + 1) % steps;
      for (var j = 0; j < tube; j++) {
        final j2 = (j + 1) % tube;
        final a = i * tube + j;
        final b = i2 * tube + j;
        final c = i2 * tube + j2;
        final d = i * tube + j2;
        faces.addAll([a, b, c, a, c, d]);
      }
    }
    return fromParts(positions, normals, faces);
  }
}
