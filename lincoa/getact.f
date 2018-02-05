      SUBROUTINE GETACT (N,M,AMAT,B,NACT,IACT,QFAC,RFAC,SNORM,
     1  RESNEW,RESACT,G,DW,VLAM,W)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION AMAT(N,*),B(*),IACT(*),QFAC(N,*),RFAC(*),
     1  RESNEW(*),RESACT(*),G(*),DW(*),VLAM(*),W(*)
C
C     N, M, AMAT, B, NACT, IACT, QFAC and RFAC are the same as the terms
C       with these names in SUBROUTINE LINCOB. The current values must be
C       set on entry. NACT, IACT, QFAC and RFAC are kept up to date when
C       GETACT changes the current active set.
C     SNORM, RESNEW, RESACT, G and DW are the same as the terms with these
C       names in SUBROUTINE TRSTEP. The elements of RESNEW and RESACT are
C       also kept up to date.
C     VLAM and W are used for working space, the vector VLAM being reserved
C       for the Lagrange multipliers of the calculation. Their lengths must
C       be at least N.
C     The main purpose of GETACT is to pick the current active set. It is
C       defined by the property that the projection of -G into the space
C       orthogonal to the active constraint normals is as large as possible,
C       subject to this projected steepest descent direction moving no closer
C       to the boundary of every constraint whose current residual is at most
C       0.2*SNORM. On return, the settings in NACT, IACT, QFAC and RFAC are
C       all appropriate to this choice of active set.
C     Occasionally this projected direction is zero, and then the final value
C       of W(1) is set to zero. Otherwise, the direction itself is returned
C       in DW, and W(1) is set to the square of the length of the direction.
C
C     Set some constants and a temporary VLAM.
C
      ONE=1.0D0
      TINY=1.0D-60
      ZERO=0.0D0
      TDEL=0.2D0*SNORM
      DDSAV=ZERO
      DO 10 I=1,N
      DDSAV=DDSAV+G(I)**2
   10 VLAM(I)=ZERO
      DDSAV=DDSAV+DDSAV
C
C     Set the initial QFAC to the identity matrix in the case NACT=0.
C
      IF (NACT .EQ. 0) THEN
          DO 30 I=1,N
          DO 20 J=1,N
   20     QFAC(I,J)=ZERO
   30     QFAC(I,I)=ONE
          GOTO 100
      END IF
C
C     Remove any constraints from the initial active set whose residuals
C       exceed TDEL.
C
      IFLAG=1
      IC=NACT
   40 IF (RESACT(IC) .GT. TDEL) GOTO 800
   50 IC=IC-1
      IF (IC .GT. 0) GOTO 40
C
C     Remove any constraints from the initial active set whose Lagrange
C       multipliers are nonnegative, and set the surviving multipliers.
C
      IFLAG=2
   60 IF (NACT .EQ. 0) GOTO 100
      IC=NACT
   70 TEMP=ZERO
      DO 80 I=1,N
   80 TEMP=TEMP+QFAC(I,IC)*G(I)
      IDIAG=(IC*IC+IC)/2
      IF (IC .LT. NACT) THEN
          JW=IDIAG+IC
          DO 90 J=IC+1,NACT
          TEMP=TEMP-RFAC(JW)*VLAM(J)
   90     JW=JW+J
      END IF
      IF (TEMP .GE. ZERO) GOTO 800
      VLAM(IC)=TEMP/RFAC(IDIAG)
      IC=IC-1
      IF (IC .GT. 0) GOTO 70
C
C     Set the new search direction D. Terminate if the 2-norm of D is zero
C       or does not decrease, or if NACT=N holds. The situation NACT=N
C       occurs for sufficiently large SNORM if the origin is in the convex
C       hull of the constraint gradients.
C
  100 IF (NACT .EQ. N) GOTO 290
      DO 110 J=NACT+1,N
      W(J)=ZERO
      DO 110 I=1,N
  110 W(J)=W(J)+QFAC(I,J)*G(I)
      DD=ZERO
      DO 130 I=1,N
      DW(I)=ZERO
      DO 120 J=NACT+1,N
  120 DW(I)=DW(I)-W(J)*QFAC(I,J)
  130 DD=DD+DW(I)**2
      IF (DD .GE. DDSAV) GOTO 290
      IF (DD .EQ. ZERO) GOTO 300
      DDSAV=DD
      DNORM=DSQRT(DD)
C
C     Pick the next integer L or terminate, a positive value of L being
C       the index of the most violated constraint. The purpose of CTOL
C       below is to estimate whether a positive value of VIOLMX may be
C       due to computer rounding errors.
C
      L=0
      IF (M .GT. 0) THEN
          TEST=DNORM/SNORM
          VIOLMX=ZERO
          DO 150 J=1,M
          IF (RESNEW(J) .GT. ZERO .AND. RESNEW(J) .LE. TDEL) THEN
              SUM=ZERO
              DO 140 I=1,N
  140         SUM=SUM+AMAT(I,J)*DW(I)
              IF (SUM .GT. TEST*RESNEW(J)) THEN
                  IF (SUM .GT. VIOLMX) THEN
                      L=J
                      VIOLMX=SUM
                  END IF
              END IF
          END IF
  150     CONTINUE
          CTOL=ZERO
          TEMP=0.01D0*DNORM
          IF (VIOLMX .GT. ZERO .AND. VIOLMX .LT. TEMP) THEN
              IF (NACT .GT. 0) THEN
                  DO 170 K=1,NACT
                  J=IACT(K)
                  SUM=ZERO
                  DO 160 I=1,N
  160             SUM=SUM+DW(I)*AMAT(I,J)
  170             CTOL=DMAX1(CTOL,DABS(SUM))
              END IF
          END IF
      END IF
      W(1)=ONE
      IF (L .EQ. 0) GOTO 300
      IF (VIOLMX .LE. 10.0D0*CTOL) GOTO 300
C
C     Apply Givens rotations to the last (N-NACT) columns of QFAC so that
C       the first (NACT+1) columns of QFAC are the ones required for the
C       addition of the L-th constraint, and add the appropriate column
C       to RFAC.
C
      NACTP=NACT+1
      IDIAG=(NACTP*NACTP-NACTP)/2
      RDIAG=ZERO
      DO 200 J=N,1,-1
      SPROD=ZERO
      DO 180 I=1,N
  180 SPROD=SPROD+QFAC(I,J)*AMAT(I,L)
      IF (J .LE. NACT) THEN
          RFAC(IDIAG+J)=SPROD
      ELSE
          IF (DABS(RDIAG) .LE. 1.0D-20*DABS(SPROD)) THEN
              RDIAG=SPROD
          ELSE
              TEMP=DSQRT(SPROD*SPROD+RDIAG*RDIAG)
              COSV=SPROD/TEMP
              SINV=RDIAG/TEMP
              RDIAG=TEMP
              DO 190 I=1,N
              TEMP=COSV*QFAC(I,J)+SINV*QFAC(I,J+1)
              QFAC(I,J+1)=-SINV*QFAC(I,J)+COSV*QFAC(I,J+1)
  190         QFAC(I,J)=TEMP
          END IF
      END IF
  200 CONTINUE
      IF (RDIAG .LT. ZERO) THEN
          DO 210 I=1,N
  210     QFAC(I,NACTP)=-QFAC(I,NACTP)
      END IF
      RFAC(IDIAG+NACTP)=DABS(RDIAG)
      NACT=NACTP
      IACT(NACT)=L
      RESACT(NACT)=RESNEW(L)
      VLAM(NACT)=ZERO
      RESNEW(L)=ZERO
C
C     Set the components of the vector VMU in W.
C
  220 W(NACT)=ONE/RFAC((NACT*NACT+NACT)/2)**2
      IF (NACT .GT. 1) THEN
          DO 240 I=NACT-1,1,-1
          IDIAG=(I*I+I)/2
          JW=IDIAG+I
          SUM=ZERO
          DO 230 J=I+1,NACT
          SUM=SUM-RFAC(JW)*W(J)
  230     JW=JW+J
  240     W(I)=SUM/RFAC(IDIAG)
      END IF
C
C     Calculate the multiple of VMU to subtract from VLAM, and update VLAM.
C
      VMULT=VIOLMX
      IC=0
      J=1
  250 IF (J .LT. NACT) THEN
          IF (VLAM(J) .GE. VMULT*W(J)) THEN
              IC=J
              VMULT=VLAM(J)/W(J)
          END IF
          J=J+1
          GOTO 250
      END IF
      DO 260 J=1,NACT
  260 VLAM(J)=VLAM(J)-VMULT*W(J)
      IF (IC .GT. 0) VLAM(IC)=ZERO
      VIOLMX=DMAX1(VIOLMX-VMULT,ZERO)
      IF (IC .EQ. 0) VIOLMX=ZERO
C
C     Reduce the active set if necessary, so that all components of the
C       new VLAM are negative, with resetting of the residuals of the
C       constraints that become inactive.
C
      IFLAG=3
      IC=NACT
  270 IF (VLAM(IC) .LT. ZERO) GOTO 280
      RESNEW(IACT(IC))=DMAX1(RESACT(IC),TINY)
      GOTO 800
  280 IC=IC-1
      IF (IC .GT. 0) GOTO 270
C
C     Calculate the next VMU if VIOLMX is positive. Return if NACT=N holds,
C       as then the active constraints imply D=0. Otherwise, go to label
C       100, to calculate the new D and to test for termination.
C
      IF (VIOLMX .GT. ZERO) GOTO 220
      IF (NACT .LT. N) GOTO 100
  290 DD=ZERO
  300 W(1)=DD
      RETURN
C
C     These instructions rearrange the active constraints so that the new
C       value of IACT(NACT) is the old value of IACT(IC). A sequence of
C       Givens rotations is applied to the current QFAC and RFAC. Then NACT
C       is reduced by one.
C
  800 RESNEW(IACT(IC))=DMAX1(RESACT(IC),TINY)
      JC=IC
  810 IF (JC .LT. NACT) THEN
          JCP=JC+1
          IDIAG=JC*JCP/2
          JW=IDIAG+JCP
          TEMP=DSQRT(RFAC(JW-1)**2+RFAC(JW)**2)
          CVAL=RFAC(JW)/TEMP
          SVAL=RFAC(JW-1)/TEMP
          RFAC(JW-1)=SVAL*RFAC(IDIAG)
          RFAC(JW)=CVAL*RFAC(IDIAG)
          RFAC(IDIAG)=TEMP
          IF (JCP .LT. NACT) THEN
              DO 820 J=JCP+1,NACT
              TEMP=SVAL*RFAC(JW+JC)+CVAL*RFAC(JW+JCP)
              RFAC(JW+JCP)=CVAL*RFAC(JW+JC)-SVAL*RFAC(JW+JCP)
              RFAC(JW+JC)=TEMP
  820         JW=JW+J
          END IF
          JDIAG=IDIAG-JC
          DO 830 I=1,N
          IF (I .LT. JC) THEN
              TEMP=RFAC(IDIAG+I)
              RFAC(IDIAG+I)=RFAC(JDIAG+I)
              RFAC(JDIAG+I)=TEMP
          END IF
          TEMP=SVAL*QFAC(I,JC)+CVAL*QFAC(I,JCP)
          QFAC(I,JCP)=CVAL*QFAC(I,JC)-SVAL*QFAC(I,JCP)
  830     QFAC(I,JC)=TEMP
          IACT(JC)=IACT(JCP)
          RESACT(JC)=RESACT(JCP)
          VLAM(JC)=VLAM(JCP)
          JC=JCP
          GOTO 810
      END IF
      NACT=NACT-1
      GOTO (50,60,280),IFLAG
      END
