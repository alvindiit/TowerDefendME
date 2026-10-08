using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Numerics;
using System.Text;

public static class RockGlbGenerator
{
    private sealed class Face
    {
        public Vector3 A, B, C;
        public Face(Vector3 a, Vector3 b, Vector3 c) { A = a; B = b; C = c; }
    }

    private static readonly float[,] Profiles = {
        {0.00f,0.70f},{0.12f,0.91f},{0.36f,1.00f},{0.64f,0.87f},{0.84f,0.66f},{0.94f,0.29f}
    };
    private static readonly float[,] Shapes = {
        {0.92f,0.80f,0.78f,13},{0.76f,0.98f,1.08f,12},{1.08f,0.74f,0.91f,14},
        {0.88f,1.05f,0.72f,13},{1.13f,0.90f,1.18f,15},{0.73f,0.82f,0.96f,12}
    };
    private static readonly Vector3[] Palettes = {
        new Vector3(0.37f,0.39f,0.36f), new Vector3(0.43f,0.41f,0.36f),
        new Vector3(0.34f,0.38f,0.37f), new Vector3(0.42f,0.39f,0.34f),
        new Vector3(0.36f,0.38f,0.35f), new Vector3(0.40f,0.40f,0.38f)
    };

    private static Vector3 Unit(Vector3 v) { return Vector3.Normalize(v); }
    private static void AddFace(List<Face> faces, Vector3 a, Vector3 b, Vector3 c, Vector3 expected)
    {
        Vector3 n = Vector3.Cross(b - a, c - a);
        if (Vector3.Dot(n, expected) < 0) { Vector3 t = b; b = c; c = t; }
        faces.Add(new Face(a, b, c));
    }

    public static void GenerateAll(string directory)
    {
        Directory.CreateDirectory(directory);
        for (int i = 0; i < 6; i++) Generate(directory, i);
    }

    private static void Generate(string directory, int variant)
    {
        float width = Shapes[variant,0], depth = Shapes[variant,1], height = Shapes[variant,2];
        int sides = (int)Shapes[variant,3];
        Random random = new Random(4700 + variant * 173);
        double phase = random.NextDouble() * Math.PI * 2.0;
        float offsetX = ((float)random.NextDouble() * 0.16f - 0.08f) * width;
        float offsetZ = ((float)random.NextDouble() * 0.16f - 0.08f) * depth;
        Vector3[][] rings = new Vector3[6][];
        for (int r = 0; r < 6; r++)
        {
            rings[r] = new Vector3[sides];
            for (int i = 0; i < sides; i++)
            {
                double angle = 2.0 * Math.PI * i / sides + phase + (random.NextDouble() * 0.18 - 0.09);
                double lobe = 1.0 + 0.15 * Math.Sin(angle * 3.0 + variant * 0.81) + 0.08 * Math.Sin(angle * 5.0 - variant);
                double rough = 0.90 + random.NextDouble() * 0.18;
                double radius = Profiles[r,1] * lobe * rough;
                double shift = r / 5.0;
                float x = offsetX * (float)shift + (float)Math.Sin(angle * 2.0 + variant) * 0.035f * width * (float)shift + (float)Math.Cos(angle) * width * 0.5f * (float)radius;
                float z = offsetZ * (float)shift + (float)Math.Cos(angle * 3.0 - variant) * 0.03f * depth * (float)shift + (float)Math.Sin(angle) * depth * 0.5f * (float)radius;
                float yJitter = r == 0 ? 0 : ((float)random.NextDouble() * 0.07f - 0.035f) * height;
                rings[r][i] = new Vector3(x, Math.Max(0, Profiles[r,0] * height + yJitter), z);
            }
        }

        List<Face> faces = new List<Face>();
        Vector3 bottom = new Vector3(offsetX * 0.3f, 0.012f * height, offsetZ * 0.3f);
        for (int i = 0; i < sides; i++) AddFace(faces, bottom, rings[0][(i + 1) % sides], rings[0][i], new Vector3(0,-1,0));
        for (int r = 0; r < 5; r++) for (int i = 0; i < sides; i++)
        {
            int j = (i + 1) % sides;
            Vector3 a = rings[r][i], b = rings[r][j], c = rings[r + 1][i], d = rings[r + 1][j];
            Vector3 radial = new Vector3((a.X+b.X+c.X+d.X)*0.25f, 0.08f, (a.Z+b.Z+c.Z+d.Z)*0.25f);
            AddFace(faces, a, b, c, radial); AddFace(faces, b, d, c, radial);
        }
        Vector3 crest = new Vector3(offsetX * 0.55f, height * 0.91f, offsetZ * 0.55f);
        for (int i = 0; i < sides; i++) AddFace(faces, rings[5][i], rings[5][(i + 1) % sides], crest, new Vector3(0,1,0));

        List<Vector3> positions = new List<Vector3>(), normals = new List<Vector3>();
        List<Vector4> colors = new List<Vector4>();
        Vector3 palette = Palettes[variant];
        for (int f = 0; f < faces.Count; f++)
        {
            Face face = faces[f];
            Vector3 normal = Unit(Vector3.Cross(face.B - face.A, face.C - face.A));
            float shade = (0.83f + (float)random.NextDouble() * 0.30f) * (0.94f + Math.Max(normal.Y, 0) * 0.09f);
            Vector4 color = new Vector4(Math.Min(1,palette.X*shade), Math.Min(1,palette.Y*shade), Math.Min(1,palette.Z*shade), 1);
            positions.Add(face.A); positions.Add(face.B); positions.Add(face.C);
            normals.Add(normal); normals.Add(normal); normals.Add(normal);
            colors.Add(color); colors.Add(color); colors.Add(color);
        }

        List<uint> indices = new List<uint>();
        for (uint i = 0; i < positions.Count; i++) indices.Add(i);
        MemoryStream binary = new MemoryStream();
        BinaryWriter writer = new BinaryWriter(binary);
        int posOffset = WriteVec3(writer, positions), normOffset = WriteVec3(writer, normals), colorOffset = WriteVec4(writer, colors);
        int indexOffset = (int)binary.Position;
        foreach (uint index in indices) writer.Write(index);
        int binaryLength = (int)binary.Length;
        while (binary.Length % 4 != 0) writer.Write((byte)0);

        Vector3 min = positions[0], max = positions[0];
        foreach (Vector3 p in positions) { min = Vector3.Min(min,p); max = Vector3.Max(max,p); }
        CultureInfo inv = CultureInfo.InvariantCulture;
        string json = String.Format(inv,
            "{{\"asset\":{{\"version\":\"2.0\",\"generator\":\"TowerDefendME Rock Mesh Builder\"}},\"scene\":0,\"scenes\":[{{\"nodes\":[0]}}],\"nodes\":[{{\"name\":\"rock_{0:00}\",\"mesh\":0}}],\"meshes\":[{{\"name\":\"IrregularRock_{0:00}\",\"primitives\":[{{\"attributes\":{{\"POSITION\":0,\"NORMAL\":1,\"COLOR_0\":2}},\"indices\":3,\"material\":0,\"mode\":4}}]}}],\"materials\":[{{\"name\":\"WeatheredRock_{0:00}\",\"pbrMetallicRoughness\":{{\"baseColorFactor\":[0.34,0.31,0.27,1],\"metallicFactor\":0,\"roughnessFactor\":0.84}}}}],\"buffers\":[{{\"byteLength\":{1}}}],\"bufferViews\":[{{\"buffer\":0,\"byteOffset\":0,\"byteLength\":{2},\"target\":34962}},{{\"buffer\":0,\"byteOffset\":{3},\"byteLength\":{4},\"target\":34962}},{{\"buffer\":0,\"byteOffset\":{5},\"byteLength\":{6},\"target\":34962}},{{\"buffer\":0,\"byteOffset\":{7},\"byteLength\":{8},\"target\":34963}}],\"accessors\":[{{\"bufferView\":0,\"componentType\":5126,\"count\":{9},\"type\":\"VEC3\",\"min\":[{10},{11},{12}],\"max\":[{13},{14},{15}]}},{{\"bufferView\":1,\"componentType\":5126,\"count\":{9},\"type\":\"VEC3\"}},{{\"bufferView\":2,\"componentType\":5126,\"count\":{9},\"type\":\"VEC4\"}},{{\"bufferView\":3,\"componentType\":5125,\"count\":{16},\"type\":\"SCALAR\",\"min\":[0],\"max\":[{17}]}}]}}",
            variant + 1, binaryLength, positions.Count * 12, positions.Count * 12, positions.Count * 12, positions.Count * 16, positions.Count * 16, indexOffset, indices.Count * 4, positions.Count, min.X, min.Y, min.Z, max.X, max.Y, max.Z, indices.Count, indices.Count - 1);
        byte[] jsonBytes = Encoding.UTF8.GetBytes(json);
        int jsonPaddedLength = (jsonBytes.Length + 3) & ~3;
        int total = 12 + 8 + jsonPaddedLength + 8 + (int)binary.Length;
        string path = Path.Combine(directory, String.Format("rock_{0:00}.glb", variant + 1));
        using (FileStream file = File.Create(path)) using (BinaryWriter glb = new BinaryWriter(file))
        {
            glb.Write(0x46546C67); glb.Write(2); glb.Write(total);
            glb.Write(jsonPaddedLength); glb.Write(0x4E4F534A); glb.Write(jsonBytes);
            for (int i = jsonBytes.Length; i < jsonPaddedLength; i++) glb.Write((byte)0x20);
            glb.Write((int)binary.Length); glb.Write(0x004E4942); glb.Write(binary.ToArray());
        }
    }

    private static int WriteVec3(BinaryWriter writer, List<Vector3> values)
    {
        int offset = (int)writer.BaseStream.Position;
        foreach (Vector3 v in values) { writer.Write(v.X); writer.Write(v.Y); writer.Write(v.Z); }
        return offset;
    }
    private static int WriteVec4(BinaryWriter writer, List<Vector4> values)
    {
        int offset = (int)writer.BaseStream.Position;
        foreach (Vector4 v in values) { writer.Write(v.X); writer.Write(v.Y); writer.Write(v.Z); writer.Write(v.W); }
        return offset;
    }
}
