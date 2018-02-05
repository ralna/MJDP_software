      SUBROUTINE LINCOA (N,NPT,M,A,IA,B,X,RHOBEG,RHOEND,IPRINT,
     1  MAXFUN,W)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION A(IA,*),B(*),X(*),W(*)
C
C     This subroutine seeks the least value of a function of many variables,
C       subject to general linear inequality constraints, by a trust region
C       method that forms quadratic models by interpolation. Usually there
C       is much freedom in each new model after satisfying the interpolation
C       conditions, which is taken up by minimizing the Frobenius norm of
C       the change to the second derivative matrix of the model. One new
C       function value is calculated on each iteration, usually at a point
C       where the current model predicts a reduction in the least value so
C       far of the objective function subject to the linear constraints.
C       Alternatively, a new vector of variables may be chosen to replace
C       an interpolation point that may be too far away for reliability, and
C       then the new point does not have to satisfy the linear constraints.
C       The arguments of the subroutine are as follows.
C
C     N must be set to the number of variables and must be at least two.
C     NPT must be set to the number of interpolation conditions, which is
C       required to be in the interval [N+2,(N+1)(N+2)/2]. Typical choices
C       of the author are NPT=N+6 and NPT=2*N+1. Larger values tend to be
C       highly inefficent when the number of variables is substantial, due
C       to the amount of work and extra difficulty of adjusting more points.
C     M must be set to the number of linear inequality constraints.
C     A is a matrix whose columns are the constraint gradients, which are
C       required to be nonzero.
C     IA is the first dimension of the array A, which must be at least N.
C     B is the vector of right hand sides of the constraints, the J-th
C       constraint being that the scalar product of A(.,J) with X(.) is at
C       most B(J). The initial vector X(.) is made feasible by increasing
C       the value of B(J) if necessary.
C     X is the vector of variables. Initial values of X(1),X(2),...,X(N)
C       must be supplied. If they do not satisfy the constraints, then B
C       is increased as mentioned above. X contains on return the variables
C       that have given the least calculated F subject to the constraints.
C     RHOBEG and RHOEND must be set to the initial and final values of a
C       trust region radius, so both must be positive with RHOEND<=RHOBEG.
C       Typically, RHOBEG should be about one tenth of the greatest expected
C       change to a variable, and RHOEND should indicate the accuracy that
C       is required in the final values of the variables.
C     The value of IPRINT should be set to 0, 1, 2 or 3, which controls the
C       amount of printing. Specifically, there is no output if IPRINT=0 and
C       there is output only at the return if IPRINT=1. Otherwise, the best
C       feasible vector of variables so far and the corresponding value of
C       the objective function are printed whenever RHO is reduced, where
C       RHO is the current lower bound on the trust region radius. Further,
C       each new value of F with its variables are output if IPRINT=3.
C     MAXFUN must be set to an upper bound on the number of calls of CALFUN,
C       its value being at least NPT+1.
C     W is an array used for working space. Its length must be at least
C       M*(2+N) + NPT*(4+N+NPT) + N*(9+3*N) + MAX [ M+3*N, 2*M+N, 2*NPT ].
C       On return, W(1) is set to the final value of F, and W(2) is set to
C       the total number of function evaluations plus 0.5.
C
C     SUBROUTINE CALFUN (N,X,F) has to be provided by the user. It must set
C       F to the value of the objective function for the variables X(1),
C       X(2),...,X(N). The value of the argument F is positive when CALFUN
C       is called if and only if the current X satisfies the constraints
C       to working accuracy.
C
C     Check that N, NPT and MAXFUN are acceptable.
C
      ZERO=0.0D0
      SMALLX=1.0D-6*RHOEND
      NP=N+1
      NPTM=NPT-NP
      IF (N .LE. 1) THEN
          PRINT 10
   10     FORMAT (/4X,'Return from LINCOA because N is less than 2.')
          GOTO 80
      END IF
      IF (NPT .LT. N+2 .OR. NPT .GT. ((N+2)*NP)/2) THEN
          PRINT 20
   20     FORMAT (/4X,'Return from LINCOA because NPT is not in',
     1      ' the required interval.')
          GOTO 80
      END IF
      IF (MAXFUN .LE. NPT) THEN
          PRINT 30
   30     FORMAT (/4X,'Return from LINCOA because MAXFUN is less',
     1      ' than NPT+1.')
          GOTO 80
      END IF
C
C     Normalize the constraints, and copy the resultant constraint matrix
C       and right hand sides into working space, after increasing the right
C       hand sides if necessary so that the starting point is feasible.
C
      IAMAT=MAX0(M+3*N,2*M+N,2*NPT)+1
      IB=IAMAT+M*N
      IFLAG=0
      IF (M .GT. 0) THEN
          IW=IAMAT-1
          DO 60 J=1,M
          SUM=ZERO
          TEMP=ZERO
          DO 40 I=1,N
          SUM=SUM+A(I,J)*X(I)
   40     TEMP=TEMP+A(I,J)**2
          IF (TEMP .EQ. ZERO) THEN
              PRINT 50
   50         FORMAT (/4X,'Return from LINCOA because the gradient of',
     1          ' a constraint is zero.')
              GOTO 80
          END IF
          TEMP=DSQRT(TEMP)
          IF (SUM-B(J) .GT. SMALLX*TEMP) IFLAG=1
          W(IB+J-1)=DMAX1(B(J),SUM)/TEMP
          DO 60 I=1,N
          IW=IW+1
   60     W(IW)=A(I,J)/TEMP
      END IF
      IF (IFLAG .EQ. 1) THEN
          IF (IPRINT .GT. 0) PRINT 70
   70     FORMAT (/4X,'LINCOA has made the initial X feasible by',
     1      ' increasing part(s) of B.')
      END IF
C
C     Partition the working space array, so that different parts of it can be
C     treated separately by the subroutine that performs the main calculation.
C
      NDIM=NPT+N
      IXB=IB+M
      IXP=IXB+N
      IFV=IXP+N*NPT
      IXS=IFV+NPT
      IXO=IXS+N
      IGO=IXO+N
      IHQ=IGO+N
      IPQ=IHQ+(N*NP)/2
      IBMAT=IPQ+NPT
      IZMAT=IBMAT+NDIM*N
      ISTP=IZMAT+NPT*NPTM
      ISP=ISTP+N
      IXN=ISP+NPT+NPT
      IAC=IXN+N
      IRC=IAC+N
      IQF=IRC+M
      IRF=IQF+N*N
      IPQW=IRF+(N*NP)/2
C
C     The above settings provide a partition of W for subroutine LINCOB.
C
      CALL LINCOB (N,NPT,M,W(IAMAT),W(IB),X,RHOBEG,RHOEND,IPRINT,
     1  MAXFUN,W(IXB),W(IXP),W(IFV),W(IXS),W(IXO),W(IGO),W(IHQ),
     2  W(IPQ),W(IBMAT),W(IZMAT),NDIM,W(ISTP),W(ISP),W(IXN),W(IAC),
     3  W(IRC),W(IQF),W(IRF),W(IPQW),W)
   80 RETURN
      END
