import simd

/// A planar projective transform from space `From` to space `To`,
/// using column vectors: p' ~ H · [x, y, 1]ᵀ, normalized so H[2][2] = 1.
public struct Homography<From: CoordinateSpace, To: CoordinateSpace>: Sendable {
    /// Column-major (simd convention): `matrix[col][row]`.
    public let matrix: simd_double3x3

    public init(matrix: simd_double3x3) { self.matrix = matrix }

    /// Solves the unique homography taking four source points to four destination points.
    /// Returns nil when the points are degenerate (three or more collinear).
    public init?(from source: [Point<From>], to destination: [Point<To>]) {
        guard source.count == 4, destination.count == 4 else { return nil }
        // Unknowns h = [h11 h12 h13 h21 h22 h23 h31 h32], h33 = 1.
        var a = [[Double]](repeating: [Double](repeating: 0, count: 9), count: 8)
        for i in 0..<4 {
            let (x, y) = (source[i].x, source[i].y)
            let (u, v) = (destination[i].x, destination[i].y)
            a[2 * i]     = [x, y, 1, 0, 0, 0, -u * x, -u * y, u]
            a[2 * i + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v]
        }
        guard let h = LinearSolver.solve(augmented: a) else { return nil }
        // Rows of H → simd columns.
        self.matrix = simd_double3x3(rows: [
            SIMD3(h[0], h[1], h[2]),
            SIMD3(h[3], h[4], h[5]),
            SIMD3(h[6], h[7], 1),
        ])
        guard abs(matrix.determinant) > Self.degeneracyThreshold else { return nil }
    }

    public func apply(_ p: Point<From>) -> Point<To> {
        let q = matrix * SIMD3(p.x, p.y, 1)
        return Point<To>(x: q.x / q.z, y: q.y / q.z)
    }
}

/// Gaussian elimination with partial pivoting on an n×(n+1) augmented matrix.
enum LinearSolver {
    static func solve(augmented input: [[Double]], epsilon: Double = 1e-12) -> [Double]? {
        var m = input
        let n = m.count
        for col in 0..<n {
            guard let pivot = (col..<n).max(by: { abs(m[$0][col]) < abs(m[$1][col]) }),
                  abs(m[pivot][col]) > epsilon else { return nil }
            m.swapAt(col, pivot)
            for row in 0..<n where row != col {
                let f = m[row][col] / m[col][col]
                if f == 0 { continue }
                for k in col...n { m[row][k] -= f * m[col][k] }
            }
        }
        return (0..<n).map { m[$0][n] / m[$0][$0] }
    }
}

// MARK: - Algebra
extension Homography {
    /// Below this |det|, H collapses the plane onto a line (e.g. three collinear corners).
    static var degeneracyThreshold: Double { 1e-9 }

    public func inverted() -> Homography<To, From>? {
        guard abs(matrix.determinant) > Self.degeneracyThreshold else { return nil }
        let inv = matrix.inverse
        return Homography<To, From>(matrix: inv * (1 / inv[2][2]))
    }

    /// Composition: `(lhs * rhs).apply(p) == lhs.apply(rhs.apply(p))`.
    public static func * <Mid>(lhs: Homography<Mid, To>, rhs: Homography<From, Mid>) -> Homography<From, To> {
        let m = lhs.matrix * rhs.matrix
        return Homography(matrix: m * (1 / m[2][2]))
    }

    /// The same transform for row-vector APIs ([x y 1] · M), i.e. the transpose of H.
    public var rowVectorElements: ProjectiveElements {
        let c = matrix // c[col][row]; transpose means element (r,c) of M = H(c,r) = matrix[r][c]
        return ProjectiveElements(
            m11: c[0][0], m12: c[0][1], m13: c[0][2],
            m21: c[1][0], m22: c[1][1], m23: c[1][2],
            m31: c[2][0], m32: c[2][1], m33: c[2][2])
    }
}

/// Nine elements in row-vector convention (CGAffineTransform / ProjectionTransform / CATransform3D style).
public struct ProjectiveElements: Equatable, Sendable {
    public var m11, m12, m13, m21, m22, m23, m31, m32, m33: Double
}
