// ignore_for_file: avoid_print
import 'dart:math' as math;

import 'package:dart_procedural_meshes/meshes.dart';

void main() {
  var failures = 0;

  void expect(bool condition, String label) {
    if (!condition) {
      failures++;
      print('FAIL  $label');
    } else {
      print('ok    $label');
    }
  }

  void checkMesh(String name, MeshData mesh) {
    expect(mesh.vertexCount > 0, '$name has vertices');
    expect(mesh.triangleCount > 0, '$name has triangles');

    // 1. unit-length vertex normals, finite positions
    var normalsOk = true;
    for (var i = 0; i < mesh.vertexCount; i++) {
      final i3 = i * 3;
      final nl = math.sqrt(
        mesh.vertexNormals[i3] * mesh.vertexNormals[i3] +
            mesh.vertexNormals[i3 + 1] * mesh.vertexNormals[i3 + 1] +
            mesh.vertexNormals[i3 + 2] * mesh.vertexNormals[i3 + 2],
      );
      if ((nl - 1).abs() > 1e-3) normalsOk = false;
      for (var k = 0; k < 3; k++) {
        if (!mesh.positions[i3 + k].isFinite) normalsOk = false;
      }
    }
    expect(normalsOk, '$name normals unit-length + finite positions');

    // 2. face normal agrees with vertex normals (winding is outward)
    var windingOk = true;
    for (var f = 0; f < mesh.faces.length; f += 3) {
      final a = mesh.faces[f] * 3;
      final b = mesh.faces[f + 1] * 3;
      final c = mesh.faces[f + 2] * 3;
      final gx =
          (mesh.vertexNormals[a] +
              mesh.vertexNormals[b] +
              mesh.vertexNormals[c]) /
          3;
      final gy =
          (mesh.vertexNormals[a + 1] +
              mesh.vertexNormals[b + 1] +
              mesh.vertexNormals[c + 1]) /
          3;
      final gz =
          (mesh.vertexNormals[a + 2] +
              mesh.vertexNormals[b + 2] +
              mesh.vertexNormals[c + 2]) /
          3;
      final dot =
          mesh.faceNormals[f] * gx +
          mesh.faceNormals[f + 1] * gy +
          mesh.faceNormals[f + 2] * gz;
      if (dot < 0) windingOk = false;
    }
    expect(windingOk, '$name face winding matches outward normals');

    // 3. closed 2-manifold: every edge shared by exactly two triangles
    final edgeCount = <int, int>{};
    for (var f = 0; f < mesh.faces.length; f += 3) {
      final a = mesh.faces[f];
      final b = mesh.faces[f + 1];
      final c = mesh.faces[f + 2];
      for (final edge in [
        [a, b],
        [b, c],
        [c, a],
      ]) {
        final lo = edge[0] < edge[1] ? edge[0] : edge[1];
        final hi = edge[0] < edge[1] ? edge[1] : edge[0];
        final key = (lo << 20) | hi;
        edgeCount[key] = (edgeCount[key] ?? 0) + 1;
      }
    }
    final badEdges = edgeCount.values.where((v) => v != 2).length;
    expect(badEdges == 0, '$name closed manifold ($badEdges bad edges)');

    // 4. roughly centred in a unit-ish volume
    var maxR = 0.0;
    for (var i = 0; i < mesh.vertexCount; i++) {
      final i3 = i * 3;
      final r = math.sqrt(
        mesh.positions[i3] * mesh.positions[i3] +
            mesh.positions[i3 + 1] * mesh.positions[i3 + 1] +
            mesh.positions[i3 + 2] * mesh.positions[i3 + 2],
      );
      if (r > maxR) maxR = r;
    }
    expect(
      maxR > 0.4 && maxR < 2.2,
      '$name fits view (maxR=${maxR.toStringAsFixed(2)})',
    );
  }

  checkMesh('icosphere', MeshData.icosphere(2));
  checkMesh('torus', MeshData.torus());
  checkMesh('knot', MeshData.torusKnot());

  // 5. a worked projection example — the pipeline math end to end
  const focal = 300.0;
  const camDist = 3.3;
  final yaw = 0.6, pitch = -0.32;
  final cy = math.cos(yaw), sy = math.sin(yaw);
  final cp = math.cos(pitch), sp = math.sin(pitch);
  double px = 0, py = 1, pz = 0; // north pole
  final y1 = py * cp - pz * sp;
  final z1 = py * sp + pz * cp;
  final vx = px * cy + z1 * sy;
  final vy = y1;
  final vz = -px * sy + z1 * cy;
  final depth = vz + camDist;
  expect(depth > 0.2, 'north pole stays in front of camera (z=$depth)');
  final sx = 150 + vx * focal / depth;
  final syS = 300 - vy * focal / depth;
  expect(sx.isFinite && syS.isFinite, 'projection finite ($sx, $syS)');

  print(failures == 0 ? '\nALL CHECKS PASSED' : '\n$failures FAILURES');
}
